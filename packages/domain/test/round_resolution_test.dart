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

  group('voteTally', () {
    test('broji vazee glasove po predlogu; kasni i van liste se ne broje', () {
      final late = _end.add(const Duration(seconds: 1));
      final tally = voteTally(
        round: _round(),
        proposals: [_proposal('a'), _proposal('b')],
        votes: [
          _vote('v1', 'a'),
          _vote('v2', 'a'),
          _vote('v3', 'b'),
          _vote('v4', 'a', at: late), // kasni
          _vote('v5', 'nepostojeci'), // van liste
        ],
      );
      expect(tally, {const ProposalId('a'): 2, const ProposalId('b'): 1});
    });

    test('prazan zbir bez ijednog vazeg glasa', () {
      expect(
        voteTally(round: _round(), proposals: [_proposal('a')], votes: []),
        isEmpty,
      );
    });
  });

  group('carryOver', () {
    Proposal lostProposal(String id, {DateTime? at}) =>
        _proposal(id, at: at).withStatus(const Rejected());

    ProposalId nextId(Proposal p) => ProposalId('${p.id.value}-n');

    final afterEnd = _end.add(const Duration(minutes: 1));

    test('prenosi gubitnike sa glasovima, ispušta bez glasova', () {
      final carried = carryOver(
        rejected: [lostProposal('a'), lostProposal('b'), lostProposal('c')],
        round: _round(),
        votes: [_vote('v1', 'a'), _vote('v2', 'b')],
        newIdFor: nextId,
        now: afterEnd,
      );
      expect(carried.map((p) => p.id.value), ['a-n', 'b-n']);
    });

    test('kap seče po rangu: top 3 od 5 sa glasovima', () {
      final losers = [
        lostProposal('a', at: _start.add(const Duration(minutes: 10))),
        lostProposal('b', at: _start.add(const Duration(minutes: 9))),
        lostProposal('c', at: _start),
        lostProposal('d', at: _start.add(const Duration(minutes: 1))),
        lostProposal('e', at: _start.add(const Duration(minutes: 2))),
      ];
      final carried = carryOver(
        rejected: losers,
        round: _round(),
        votes: [
          _vote('v1', 'a'),
          _vote('v2', 'a'),
          _vote('v3', 'a'),
          _vote('v4', 'b'),
          _vote('v5', 'b'),
          _vote('v6', 'c'),
          _vote('v7', 'd'),
          _vote('v8', 'e'),
        ],
        newIdFor: nextId,
        now: afterEnd,
        maxCarry: 3,
      );
      // a(3), b(2), pa c kao najraniji medju izjednacenima sa 1 glasom.
      expect(carried.map((p) => p.id.value), ['a-n', 'b-n', 'c-n']);
    });

    test('kopija je sveža: now, nov ID, isti song, status Proposed', () {
      final loser = lostProposal('a');
      final carried = carryOver(
        rejected: [loser],
        round: _round(),
        votes: [_vote('v1', 'a')],
        newIdFor: nextId,
        now: afterEnd,
      );
      expect(carried, hasLength(1));
      final copy = carried.single;
      expect(copy.id, isNot(loser.id));
      expect(copy.proposedAt, afterEnd);
      expect(copy.song, loser.song);
      expect(copy.roomId, loser.roomId);
      expect(copy.proposedBy, loser.proposedBy);
      expect(copy.status, isA<Proposed>());
    });

    test('ne-Rejected u ulazu se ignoriše; maxCarry 0 gasi prenos', () {
      final notLoser = _proposal('x');
      expect(
        carryOver(
          rejected: [notLoser],
          round: _round(),
          votes: [_vote('v1', 'x')],
          newIdFor: nextId,
          now: afterEnd,
        ),
        isEmpty,
      );
      expect(
        carryOver(
          rejected: [lostProposal('a')],
          round: _round(),
          votes: [_vote('v1', 'a')],
          newIdFor: nextId,
          now: afterEnd,
          maxCarry: 0,
        ),
        isEmpty,
      );
    });

    test('kasni glas ne nosi nikoga', () {
      final late = _end.add(const Duration(seconds: 1));
      expect(
        carryOver(
          rejected: [lostProposal('a')],
          round: _round(),
          votes: [_vote('v1', 'a', at: late)],
          newIdFor: nextId,
          now: afterEnd,
        ),
        isEmpty,
      );
    });
  });
}
