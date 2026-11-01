// ModerationBloc: sekvence stanja i granica "pravilo pre porta".
//
// Po istom obrascu kao ProposalListBloc test: mock porta (mocktail),
// pravilo odbija → port se ne poziva (`verifyNever`). Pravila testira
// domenski paket — ovde se proverava da ih Bloc zove i postuje.
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

class _MockRepository extends Mock implements ProposalRepository {}

const _roomId = RoomId('r1');
const _room2Id = RoomId('r2');
const _room = Room(id: _roomId, name: 'Petak', hostId: UserId('h1'));
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
  ProposalStatus status = const InVoting(),
}) =>
    Proposal(
      id: ProposalId(id),
      roomId: _roomId,
      song: _song,
      proposedBy: const UserId('u2'),
      proposedAt: _now.subtract(const Duration(minutes: 10)),
      status: status,
    );

RoomSnapshot _snapshot({List<Proposal> proposals = const []}) => RoomSnapshot(
      room: _room,
      round: _round,
      proposals: proposals,
      votes: const [],
    );

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  ModerationBloc build() => ModerationBloc(repository: repository);

  group('ucitavanje', () {
    blocTest<ModerationBloc, ModerationState>(
      'lista soba pa izbor sobe daje snimak',
      build: build,
      setUp: () {
        when(() => repository.loadRooms()).thenAnswer(
          (_) async => const [
            _room,
            Room(id: _room2Id, name: 'Subota', hostId: UserId('h1')),
          ],
        );
        when(() => repository.loadRoom(any())).thenAnswer(
          (_) async => _snapshot(proposals: [_proposal('p1')]),
        );
      },
      act: (bloc) {
        bloc.add(const ModerationStarted());
      },
      wait: const Duration(milliseconds: 20),
      expect: () => [
        isA<ModerationLoading>(),
        isA<ModerationLoaded>().having(
          (s) => s.rooms.length,
          'broj soba',
          2,
        ),
      ],
      verify: (_) {
        verify(() => repository.loadRooms()).called(1);
      },
    );

    blocTest<ModerationBloc, ModerationState>(
      'greska porta daje ekran greske',
      build: build,
      setUp: () {
        when(() => repository.loadRooms()).thenThrow(Exception('pad'));
      },
      act: (bloc) => bloc.add(const ModerationStarted()),
      expect: () => [
        isA<ModerationLoading>(),
        isA<ModerationError>(),
      ],
    );
  });

  group('uklanjanje predloga', () {
    blocTest<ModerationBloc, ModerationState>(
      'predlog u glasanju postaje uklonjen',
      build: build,
      seed: () => ModerationLoaded(
        rooms: const [_room],
        snapshot: _snapshot(proposals: [_proposal('p1')]),
        tally: const {},
      ),
      setUp: () {
        when(
          () => repository.removeProposal(
            roomId: any(named: 'roomId'),
            proposalId: any(named: 'proposalId'),
          ),
        ).thenAnswer((_) async => _proposal('p1', status: const Removed()));
      },
      act: (bloc) =>
          bloc.add(const ModerationProposalRemoved(ProposalId('p1'))),
      expect: () => [
        isA<ModerationLoaded>().having(
          (s) => s.snapshot?.proposals.single.status,
          'status',
          isA<Removed>(),
        ),
      ],
      verify: (_) {
        verify(
          () => repository.removeProposal(
            roomId: any(named: 'roomId'),
            proposalId: any(named: 'proposalId'),
          ),
        ).called(1);
      },
    );

    blocTest<ModerationBloc, ModerationState>(
      'vec uklonjen: pravilo odbija, port se ne zove',
      build: build,
      seed: () => ModerationLoaded(
        rooms: const [_room],
        snapshot: _snapshot(proposals: [_proposal('p1', status: const Removed())]),
        tally: const {},
      ),
      act: (bloc) =>
          bloc.add(const ModerationProposalRemoved(ProposalId('p1'))),
      expect: () => [
        isA<ModerationLoaded>().having(
          (s) => s.ruleError,
          'ruleError',
          isA<ProposalNotRemovable>(),
        ),
      ],
      verify: (_) {
        verifyNever(
          () => repository.removeProposal(
            roomId: any(named: 'roomId'),
            proposalId: any(named: 'proposalId'),
          ),
        );
      },
    );
  });

  group('zatvaranje sobe', () {
    blocTest<ModerationBloc, ModerationState>(
      'otvorena soba postaje zatvorena',
      build: build,
      seed: () => ModerationLoaded(
        rooms: const [_room],
        snapshot: _snapshot(),
        tally: const {},
      ),
      setUp: () {
        when(
          () => repository.closeRoom(roomId: any(named: 'roomId')),
        ).thenAnswer(
          (_) async => _room.withStatus(const RoomClosed()),
        );
      },
      act: (bloc) => bloc.add(const ModerationRoomClosed(_roomId)),
      expect: () => [
        isA<ModerationLoaded>().having(
          (s) => s.rooms.single.status,
          'status sobe',
          isA<RoomClosed>(),
        ),
      ],
      verify: (_) {
        verify(() => repository.closeRoom(roomId: any(named: 'roomId')))
            .called(1);
      },
    );

    blocTest<ModerationBloc, ModerationState>(
      'zatvorena soba: pravilo odbija, port se ne zove',
      build: build,
      seed: () => ModerationLoaded(
        rooms: [_room.withStatus(const RoomClosed())],
        snapshot: _snapshot(),
        tally: const {},
      ),
      act: (bloc) => bloc.add(const ModerationRoomClosed(_roomId)),
      expect: () => [
        isA<ModerationLoaded>(),
      ],
      verify: (_) {
        verifyNever(
          () => repository.closeRoom(roomId: any(named: 'roomId')),
        );
      },
    );
  });
}
