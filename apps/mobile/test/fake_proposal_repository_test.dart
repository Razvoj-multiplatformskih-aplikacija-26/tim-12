// Lazni repozitorijum i demo podaci: KT1 stavke o podacima + demo pravila.
//
// Pravila sama testira domenski paket. Ovde se proverava da su demo podaci
// slozeni tako da se svako pravilo moze pokazati uzivo, i da se lazni port
// ponasa kao server (upis ostaje, greska je jednokratna, snimak je kopija).
import 'package:flutter_test/flutter_test.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mobile/data/demo_room.dart';
import 'package:radioroom_mobile/data/fake_proposal_repository.dart';

final _now = DateTime.utc(2026, 10, 31, 20);

FakeProposalRepository _repository() =>
    FakeProposalRepository(clock: () => _now, delay: Duration.zero);

void main() {
  group('demo podaci', () {
    final room = demoRoom(_now);

    test('bar 10 predloga', () {
      expect(room.proposals.length, greaterThanOrEqualTo(10));
    });

    test('zastupljeno svih 6 stanja', () {
      final states = room.proposals.map((p) => p.status.runtimeType).toSet();
      expect(states, {Proposed, InVoting, Winner, Played, Rejected, Removed});
    });

    test('runda je otvorena u trenutku pokretanja', () {
      expect(room.round.startsAt.isAfter(_now), isFalse);
      expect(room.round.endsAt.isAfter(_now), isTrue);
    });

    test('max 3: treci predlog tekuceg korisnika prolazi, cetvrti ne', () {
      expect(
        checkMaxActiveProposals(proposals: room.proposals, userId: demoUser),
        isA<RuleValid>(),
      );
      final third = Proposal(
        id: const ProposalId('px'),
        roomId: demoRoomId,
        song: const Song(title: 'Nova', artist: 'Neko'),
        proposedBy: demoUser,
        proposedAt: _now,
        status: const Proposed(),
      );
      expect(
        checkMaxActiveProposals(
          proposals: [...room.proposals, third],
          userId: demoUser,
        ),
        isA<RuleInvalid>(),
      );
    });

    test('poslednjih sat: Bohemian Rhapsody odbijena, Kisa pada prolazi', () {
      expect(
        checkNotRecentlyPlayed(
          song: const Song(title: 'Bohemian Rhapsody', artist: 'Queen'),
          played: room.proposals,
          now: _now,
        ),
        isA<RuleInvalid>(),
      );
      expect(
        checkNotRecentlyPlayed(
          song: const Song(title: 'Kiša pada', artist: 'Partibrejkers'),
          played: room.proposals,
          now: _now,
        ),
        isA<RuleValid>(),
      );
    });

    test('tekuci korisnik jos nije glasao u rundi', () {
      expect(
        checkSingleVotePerRound(
          votes: room.votes,
          voterId: demoUser,
          roundId: room.round.id,
        ),
        isA<RuleValid>(),
      );
    });
  });

  group('lazni repozitorijum', () {
    test('failNext obara samo sledeci zahtev', () async {
      final repository = _repository()..failNext = true;
      await expectLater(repository.loadRoom(demoRoomId), throwsException);
      expect(repository.failNext, isFalse);
      await expectLater(repository.loadRoom(demoRoomId), completes);
    });

    test('upis ostaje i dobija nove ID-jeve', () async {
      final repository = _repository();
      final proposal = await repository.propose(
        roomId: demoRoomId,
        song: const Song(title: 'Nova', artist: 'Neko'),
        proposedBy: demoUser,
      );
      final vote = await repository.vote(
        roundId: const RoundId('rd2'),
        proposalId: const ProposalId('p4'),
        voterId: demoUser,
      );
      expect(proposal.id, const ProposalId('p13'));
      expect(vote.id, const VoteId('v4'));

      final room = await repository.loadRoom(demoRoomId);
      expect(room.proposals, contains(proposal));
      expect(room.votes, contains(vote));
    });

    test('snimak je kopija: kasniji upis ga ne menja', () async {
      final repository = _repository();
      final before = await repository.loadRoom(demoRoomId);
      final count = before.proposals.length;
      await repository.propose(
        roomId: demoRoomId,
        song: const Song(title: 'Nova', artist: 'Neko'),
        proposedBy: demoUser,
      );
      expect(before.proposals.length, count);
      expect(
        () => before.proposals.add(before.proposals.first),
        throwsUnsupportedError,
      );
    });

    test(
      'prazna soba: runda bez predloga, prvi predlog ostaje u njoj',
      () async {
        final repository = _repository();
        final empty = await repository.loadRoom(emptyRoomId);
        expect(empty.proposals, isEmpty);
        expect(empty.round.endsAt.isAfter(_now), isTrue);

        await repository.propose(
          roomId: emptyRoomId,
          song: const Song(title: 'Nova', artist: 'Neko'),
          proposedBy: demoUser,
        );
        expect(
          (await repository.loadRoom(emptyRoomId)).proposals,
          hasLength(1),
        );
        // Druga soba se ne menja.
        expect(
          (await repository.loadRoom(demoRoomId)).proposals,
          hasLength(12),
        );
      },
    );

    test('nepoznata soba baca izuzetak', () async {
      await expectLater(
        _repository().loadRoom(const RoomId('x')),
        throwsException,
      );
    });
  });
}
