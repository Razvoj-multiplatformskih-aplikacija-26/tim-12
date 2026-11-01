// Form-pravila: granicni slucajevi koji bi na odbrani smeli da se slome.
//
// Svako pravilo: slucaj koji prolazi + slucaj koji pada. Nista vise —
// getteri, `==` i `toString` se ne testiraju (potrosnja bez regresione
// vrednosti).
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

const _room = RoomId('r1');
const _user = UserId('u1');
const _other = UserId('u2');
const _song = Song(title: 'Fuego', artist: 'Elena');
final _at = DateTime.utc(2026, 10, 1, 20);

Proposal _proposal({
  String id = 'p',
  UserId by = _user,
  Song song = _song,
  ProposalStatus status = const Proposed(),
  DateTime? at,
}) => Proposal(
  id: ProposalId(id),
  roomId: _room,
  song: song,
  proposedBy: by,
  proposedAt: at ?? _at,
  status: status,
);

Vote _vote({
  String id = 'v',
  String round = 'rd1',
  String proposal = 'p',
  UserId by = _user,
  DateTime? at,
}) => Vote(
  id: VoteId(id),
  roundId: RoundId(round),
  proposalId: ProposalId(proposal),
  voterId: by,
  castAt: at ?? _at,
);

void main() {
  group('checkMaxActiveProposals', () {
    test('ispod limita prolazi', () {
      final proposals = [
        _proposal(id: 'p1'),
        _proposal(id: 'p2', status: const InVoting()),
      ];
      expect(
        checkMaxActiveProposals(proposals: proposals, userId: _user).isValid,
        isTrue,
      );
    });

    test('na limitu 3 pada; zavrseni ne trose kvotu', () {
      final full = [
        _proposal(id: 'p1'),
        _proposal(id: 'p2', status: const InVoting()),
        _proposal(id: 'p3'),
      ];
      final outcome = checkMaxActiveProposals(
        proposals: full,
        userId: _user,
      );
      expect(outcome, isA<RuleInvalid>());
      expect(
        (outcome as RuleInvalid).error,
        isA<TooManyActiveProposals>()
            .having((e) => e.activeCount, 'activeCount', 3)
            .having((e) => e.limit, 'limit', 3),
      );

      // ...ali pustena/odbijena/uklonjena ne broje: 2 aktivna + 1 pustena.
      final withPlayed = [
        ...full.take(2),
        _proposal(
          id: 'p4',
          status: Played(DateTime.utc(2026, 10, 1, 19)),
        ),
      ];
      expect(
        checkMaxActiveProposals(proposals: withPlayed, userId: _user).isValid,
        isTrue,
      );
    });

    test('tudji predlozi ne trose moju kvotu', () {
      final proposals = [
        _proposal(id: 'p1'),
        _proposal(id: 'p2'),
        _proposal(id: 'p3', by: _other),
        _proposal(id: 'p4', by: _other),
      ];
      expect(
        checkMaxActiveProposals(proposals: proposals, userId: _user).isValid,
        isTrue,
      );
    });
  });

  group('checkNotRecentlyPlayed', () {
    test('pustena pre 30 min blokira; pre 2 h ne', () {
      final played = [
        _proposal(
          id: 'old',
          status: Played(DateTime.utc(2026, 10, 1, 19, 30)),
        ),
      ];
      final now = DateTime.utc(2026, 10, 1, 20);
      expect(
        checkNotRecentlyPlayed(song: _song, played: played, now: now),
        isA<RuleInvalid>(),
      );
      expect(
        checkNotRecentlyPlayed(
          song: _song,
          played: played,
          now: DateTime.utc(2026, 10, 1, 21, 31),
        ).isValid,
        isTrue,
      );
    });

    test('ista pesma drugim slovima/razmacima i dalje je ista pesma', () {
      const disguised = Song(title: '  fuego ', artist: 'ELENA');
      final played = [
        _proposal(
          id: 'old',
          status: Played(DateTime.utc(2026, 10, 1, 19, 30)),
        ),
      ];
      expect(
        checkNotRecentlyPlayed(
          song: disguised,
          played: played,
          now: DateTime.utc(2026, 10, 1, 20),
        ),
        isA<RuleInvalid>(),
      );
    });

    test('druga pesma i ne-pusteni statusi ne blokiraju', () {
      const other = Song(title: 'Vatromet', artist: 'Neko drugi');
      final played = [
        _proposal(
          id: 'old',
          status: Played(DateTime.utc(2026, 10, 1, 19, 30)),
        ),
        _proposal(id: 'pending'),
      ];
      expect(
        checkNotRecentlyPlayed(song: other, played: played, now: _at).isValid,
        isTrue,
      );
    });
  });

  group('checkSingleVotePerRound', () {
    test('drugi glas istog slusaoca u istoj rundi pada', () {
      final votes = [_vote()];
      final outcome = checkSingleVotePerRound(
        votes: votes,
        voterId: _user,
        roundId: const RoundId('rd1'),
      );
      expect(outcome, isA<RuleInvalid>());
      expect(
        (outcome as RuleInvalid).error,
        isA<AlreadyVotedInRound>(),
      );
    });

    test('ista runda drugi slusalac, ili isti slusalac druga runda — prolazi', () {
      final votes = [_vote()];
      expect(
        checkSingleVotePerRound(
          votes: votes,
          voterId: _other,
          roundId: const RoundId('rd1'),
        ).isValid,
        isTrue,
      );
      expect(
        checkSingleVotePerRound(
          votes: votes,
          voterId: _user,
          roundId: const RoundId('rd2'),
        ).isValid,
        isTrue,
      );
    });
  });

  group('checkVoteTarget', () {
    test('samo predlog u glasanju prima glas', () {
      expect(
        checkVoteTarget(
          proposal: _proposal(status: const InVoting()),
        ).isValid,
        isTrue,
      );
      for (final status in [
        const Proposed(),
        const Winner(),
        const Rejected(),
        const Removed(),
        Played(DateTime.utc(2026, 10, 1, 19)),
      ]) {
        expect(
          checkVoteTarget(proposal: _proposal(status: status)),
          isA<RuleInvalid>(),
        );
      }
    });
  });

  group('checkRoomName', () {
    test('naziv sa slovima vazi', () {
      expect(checkRoomName(name: 'Petak').isValid, isTrue);
    });

    test('prazan naziv i sami razmaci ne vaze', () {
      for (final name in ['', '   ']) {
        final outcome = checkRoomName(name: name);
        expect(outcome, isA<RuleInvalid>());
        expect((outcome as RuleInvalid).error, isA<RoomNameEmpty>());
      }
    });
  });

  group('checkRemovable', () {    test('nezavrsen predlog sme da se ukloni', () {
      for (final status in [
        const Proposed(),
        const InVoting(),
        const Winner(),
      ]) {
        expect(
          checkRemovable(proposal: _proposal(status: status)).isValid,
          isTrue,
        );
      }
    });

    test('terminalan predlog ne sme da se ukloni', () {
      for (final status in [
        Played(DateTime.utc(2026, 10, 1, 19)),
        const Rejected(),
        const Removed(),
      ]) {
        final outcome = checkRemovable(proposal: _proposal(status: status));
        expect(outcome, isA<RuleInvalid>());
        expect((outcome as RuleInvalid).error, isA<ProposalNotRemovable>());
      }
    });
  });
}
