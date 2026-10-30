// Izracunavanje runde: pobednik, tie-break, kasni i prazni slucajevi.
//
// Zasto bas ovi: `resolveRound` je "server-pravilo u KT1" — jedina tacka gde
// se glasovi pretvaraju u odluku. Tie-break i kasni glasovi su mesta gde bi
// pogresan komparator ili filter cutao (pogresan pobednik, bez greske).
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

const _room = RoomId('r1');
final _start = DateTime.utc(2026, 10, 1, 20);
final _end = DateTime.utc(2026, 10, 1, 21);

Round _round() =>
    Round(id: const RoundId('rd1'), roomId: _room, startsAt: _start, endsAt: _end);

Proposal _proposal(String id, {DateTime? at}) => Proposal(
  id: ProposalId(id),
  roomId: _room,
  song: Song(title: 'Pesma $id', artist: 'Izvodjac'),
  proposedBy: const UserId('u1'),
  proposedAt: at ?? _start,
  status: const InVoting(),
);

Vote _vote(String id, String proposal, {DateTime? at, String voter = 'u'}) =>
    Vote(
      id: VoteId(id),
      roundId: const RoundId('rd1'),
      proposalId: ProposalId(proposal),
      voterId: UserId('$voter$id'),
      castAt: at ?? _start.add(const Duration(minutes: 5)),
    );

void main() {
  group('resolveRound', () {
    test('najvise glasova pobedjuje, broj se vraca', () {
      final outcome = resolveRound(
        round: _round(),
        proposals: [_proposal('a'), _proposal('b')],
        votes: [_vote('v1', 'a'), _vote('v2', 'a'), _vote('v3', 'b')],
      );
      expect(outcome, isA<RoundWinner>());
      final winner = outcome as RoundWinner;
      expect(winner.proposal.id, const ProposalId('a'));
      expect(winner.voteCount, 2);
    });

    test('nereseno: ranije predlozena pobedjuje (2 i 3 izjednacena)', () {
      // Dva izjednacena: a predlozen ranije.
      var outcome = resolveRound(
        round: _round(),
        proposals: [
          _proposal('a', at: _start),
          _proposal('b', at: _start.add(const Duration(minutes: 1))),
        ],
        votes: [_vote('v1', 'a'), _vote('v2', 'b')],
      );
      expect(
        (outcome as RoundWinner).proposal.id,
        const ProposalId('a'),
      );

      // Tri izjednacena: najraniji od trojice.
      outcome = resolveRound(
        round: _round(),
        proposals: [
          _proposal('a', at: _start.add(const Duration(minutes: 2))),
          _proposal('b', at: _start),
          _proposal('c', at: _start.add(const Duration(minutes: 1))),
        ],
        votes: [_vote('v1', 'a'), _vote('v2', 'b'), _vote('v3', 'c')],
      );
      expect(
        (outcome as RoundWinner).proposal.id,
        const ProposalId('b'),
      );
    });

    test('glas posle kraja runde se ne broji', () {
      final late = _end.add(const Duration(seconds: 1));
      final outcome = resolveRound(
        round: _round(),
        proposals: [_proposal('a'), _proposal('b')],
        votes: [
          _vote('v1', 'a', at: late),
          _vote('v2', 'a', at: late),
          _vote('v3', 'b'),
        ],
      );
      expect(outcome, isA<RoundWinner>());
      final winner = outcome as RoundWinner;
      expect(winner.proposal.id, const ProposalId('b'));
      expect(winner.voteCount, 1);
    });

    test('samo kasni glasovi ili prazna runda: bez pobednika', () {
      final late = _end.add(const Duration(seconds: 1));
      expect(
        resolveRound(
          round: _round(),
          proposals: [_proposal('a')],
          votes: [_vote('v1', 'a', at: late)],
        ),
        isA<RoundWithoutWinner>(),
      );
      expect(
        resolveRound(round: _round(), proposals: [_proposal('a')], votes: []),
        isA<RoundWithoutWinner>(),
      );
    });

    test('glas za nepostojeci predlog se ignorise', () {
      final outcome = resolveRound(
        round: _round(),
        proposals: [_proposal('a')],
        votes: [_vote('v1', 'nepostojeci'), _vote('v2', 'a')],
      );
      expect(outcome, isA<RoundWinner>());
      expect((outcome as RoundWinner).voteCount, 1);
    });
  });
}
