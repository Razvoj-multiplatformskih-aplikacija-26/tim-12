// ProposalListBloc: sekvence stanja i granica "pravilo pre porta".
//
// Port je mock (mocktail) da bi se dokazalo i ono sto se NE desi: kad pravilo
// iz domena odbije akciju, port se ne poziva (`verifyNever`). Pravila sama
// testira domenski paket — ovde se proverava samo da ih Bloc zove i postuje.
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

class _MockRepository extends Mock implements ProposalRepository {}

const _roomId = RoomId('r1');
const _user = UserId('u1');
const _other = UserId('u2');
const _room = Room(id: _roomId, name: 'Zurka', hostId: UserId('h1'));
const _song = Song(title: 'Fuego', artist: 'Elena');
final _now = DateTime.utc(2026, 10, 31, 20);
final _round = Round(
  id: const RoundId('rd1'),
  roomId: _roomId,
  startsAt: _now.subtract(const Duration(minutes: 5)),
  endsAt: _now.add(const Duration(minutes: 5)),
);

Proposal _proposal(
  String id, {
  UserId by = _other,
  Song song = _song,
  ProposalStatus status = const InVoting(),
}) =>
    Proposal(
      id: ProposalId(id),
      roomId: _roomId,
      song: song,
      proposedBy: by,
      proposedAt: _now.subtract(const Duration(minutes: 10)),
      status: status,
    );

Vote _vote(String id, {required String proposal, UserId by = _other}) => Vote(
      id: VoteId(id),
      roundId: _round.id,
      proposalId: ProposalId(proposal),
      voterId: by,
      castAt: _now.subtract(const Duration(minutes: 1)),
    );

RoomSnapshot _snapshot({
  List<Proposal> proposals = const [],
  List<Vote> votes = const [],
}) =>
    RoomSnapshot(
      room: _room,
      round: _round,
      proposals: proposals,
      votes: votes,
    );

ProposalsLoaded _loaded(RoomSnapshot snapshot) => ProposalsLoaded(
      snapshot: snapshot,
      tally: voteTally(
        round: snapshot.round,
        proposals: snapshot.proposals,
        votes: snapshot.votes,
      ),
    );

Matcher _ruleError<T extends ProposalRuleError>() =>
    isA<ProposalsLoaded>().having((s) => s.ruleError, 'ruleError', isA<T>());

void main() {
  late _MockRepository repository;

  setUpAll(() {
    registerFallbackValue(_song);
    registerFallbackValue(_roomId);
  });

  setUp(() => repository = _MockRepository());

  ProposalListBloc build() => ProposalListBloc(
        repository: repository,
        roomId: _roomId,
        currentUser: _user,
        clock: () => _now,
      );

  // Port odgovara sa kasnjenjem, kao pravi: bez njega bi prvi glas stigao
  // pre drugog dogadjaja i test duplog tapa ne bi video trku.
  void stubVote(Vote vote) => when(
        () => repository.vote(
          roundId: any(named: 'roundId'),
          proposalId: any(named: 'proposalId'),
          voterId: any(named: 'voterId'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return vote;
      });

  void verifyVoteCalled(int times) => verify(
        () => repository.vote(
          roundId: any(named: 'roundId'),
          proposalId: any(named: 'proposalId'),
          voterId: any(named: 'voterId'),
        ),
      ).called(times);

  void verifyNoVote() => verifyNever(
        () => repository.vote(
          roundId: any(named: 'roundId'),
          proposalId: any(named: 'proposalId'),
          voterId: any(named: 'voterId'),
        ),
      );

  void verifyNoPropose() => verifyNever(
        () => repository.propose(
          roomId: any(named: 'roomId'),
          song: any(named: 'song'),
          proposedBy: any(named: 'proposedBy'),
        ),
      );

  group('ucitavanje', () {
    final snapshot = _snapshot(
      proposals: [_proposal('p1'), _proposal('p2')],
      votes: [_vote('v1', proposal: 'p1')],
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'uspeh: Loading pa Loaded sa brojem glasova iz domena',
      setUp: () => when(
        () => repository.loadRoom(_roomId),
      ).thenAnswer((_) async => snapshot),
      build: build,
      act: (bloc) => bloc.add(const ProposalsRequested()),
      expect: () => [
        const ProposalsLoading(),
        _loaded(snapshot),
      ],
      verify: (bloc) => expect(
        (bloc.state as ProposalsLoaded).tally,
        {const ProposalId('p1'): 1},
      ),
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'soba bez predloga: Empty',
      setUp: () => when(
        () => repository.loadRoom(_roomId),
      ).thenAnswer((_) async => _snapshot()),
      build: build,
      act: (bloc) => bloc.add(const ProposalsRequested()),
      expect: () => [const ProposalsLoading(), ProposalsEmpty(_snapshot())],
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'greska porta pa "Pokusaj ponovo" oporavlja',
      setUp: () {
        var calls = 0;
        when(() => repository.loadRoom(_roomId)).thenAnswer((_) async {
          if (calls++ == 0) throw Exception('mreza');
          return snapshot;
        });
      },
      build: build,
      act: (bloc) async {
        bloc.add(const ProposalsRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProposalsRequested());
      },
      expect: () => [
        const ProposalsLoading(),
        const ProposalsError(),
        const ProposalsLoading(),
        _loaded(snapshot),
      ],
    );
  });

  group('glas', () {
    final snapshot = _snapshot(proposals: [_proposal('p1'), _proposal('p2')]);
    final myVote = _vote('v9', proposal: 'p1', by: _user);

    blocTest<ProposalListBloc, ProposalListState>(
      'prolazi: glas upisan, broj glasova uvecan',
      setUp: () => stubVote(myVote),
      build: build,
      seed: () => _loaded(snapshot),
      act: (bloc) => bloc.add(const VoteCast(ProposalId('p1'))),
      expect: () => [
        _loaded(_snapshot(proposals: snapshot.proposals, votes: [myVote])),
      ],
      verify: (_) => verifyVoteCalled(1),
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'drugi glas u rundi: AlreadyVotedInRound, port se ne zove',
      build: build,
      seed: () => _loaded(
        _snapshot(proposals: snapshot.proposals, votes: [myVote]),
      ),
      act: (bloc) => bloc.add(const VoteCast(ProposalId('p2'))),
      expect: () => [_ruleError<AlreadyVotedInRound>()],
      verify: (_) => verifyNoVote(),
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'glas za predlog van glasanja: InvalidVoteTarget, port se ne zove',
      build: build,
      seed: () => _loaded(
        _snapshot(proposals: [_proposal('p1', status: const Proposed())]),
      ),
      act: (bloc) => bloc.add(const VoteCast(ProposalId('p1'))),
      expect: () => [_ruleError<InvalidVoteTarget>()],
      verify: (_) => verifyNoVote(),
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'dupli tap: drugi glas odbija pravilo, port pozvan jednom',
      setUp: () => stubVote(myVote),
      build: build,
      seed: () => _loaded(snapshot),
      act: (bloc) => bloc
        ..add(const VoteCast(ProposalId('p1')))
        ..add(const VoteCast(ProposalId('p1'))),
      expect: () => [
        _loaded(_snapshot(proposals: snapshot.proposals, votes: [myVote])),
        _ruleError<AlreadyVotedInRound>(),
      ],
      verify: (_) => verifyVoteCalled(1),
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'greska porta pri glasu: Error',
      setUp: () => when(
        () => repository.vote(
          roundId: any(named: 'roundId'),
          proposalId: any(named: 'proposalId'),
          voterId: any(named: 'voterId'),
        ),
      ).thenThrow(Exception('mreza')),
      build: build,
      seed: () => _loaded(snapshot),
      act: (bloc) => bloc.add(const VoteCast(ProposalId('p1'))),
      expect: () => [const ProposalsError()],
    );
  });

  group('predlog', () {
    const newSong = Song(title: 'Nova', artist: 'Neko');

    blocTest<ProposalListBloc, ProposalListState>(
      'prolazi: novi predlog dodat u listu',
      setUp: () => when(
        () => repository.propose(
          roomId: _roomId,
          song: newSong,
          proposedBy: _user,
        ),
      ).thenAnswer(
        (_) async =>
            _proposal('p9', by: _user, song: newSong, status: const Proposed()),
      ),
      build: build,
      seed: () => ProposalsEmpty(_snapshot()),
      act: (bloc) => bloc.add(const ProposalAdded(newSong)),
      expect: () => [
        _loaded(
          _snapshot(
            proposals: [
              _proposal('p9',
                  by: _user, song: newSong, status: const Proposed()),
            ],
          ),
        ),
      ],
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'cetvrti aktivan predlog: TooManyActiveProposals, port se ne zove',
      build: build,
      seed: () => _loaded(
        _snapshot(
          proposals: [
            _proposal('p1', by: _user),
            _proposal('p2', by: _user),
            _proposal('p3', by: _user, status: const Proposed()),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const ProposalAdded(newSong)),
      expect: () => [_ruleError<TooManyActiveProposals>()],
      verify: (_) => verifyNoPropose(),
    );

    blocTest<ProposalListBloc, ProposalListState>(
      'pesma pustena pre 30 min: RecentlyPlayedSong, port se ne zove',
      build: build,
      seed: () => _loaded(
        _snapshot(
          proposals: [
            _proposal(
              'p1',
              status: Played(_now.subtract(const Duration(minutes: 30))),
            ),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const ProposalAdded(_song)),
      expect: () => [_ruleError<RecentlyPlayedSong>()],
      verify: (_) => verifyNoPropose(),
    );
  });
}
