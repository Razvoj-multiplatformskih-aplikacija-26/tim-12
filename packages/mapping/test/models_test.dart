// Prevod modela domen <-> DTO: krug cuva sve sto domen ima, za svako
// stanje predloga, sobe i svaku ulogu.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mapping/radioroom_mapping.dart';
import 'package:test/test.dart';

void main() {
  test('Proposal krug domen->dto->json->dto->domen za svako stanje', () {
    final statuses = <ProposalStatus>[
      const Proposed(),
      const InVoting(),
      const Winner(),
      Played(DateTime.utc(2026, 11, 20, 11, 40)),
      const Rejected(),
      const Removed(),
    ];
    for (final status in statuses) {
      final proposal = Proposal(
        id: const ProposalId('p1'),
        roomId: const RoomId('r1'),
        song: const Song(
          title: 'Fuego',
          artist: 'Severina',
          album: 'Dobro jutro',
          durationMs: 180000,
          coverUrl: 'https://example.com/c.jpg',
        ),
        proposedBy: const UserId('u1'),
        proposedAt: DateTime.utc(2026, 11, 20, 10),
        status: status,
      );

      final back = ProposalDto.fromJson(proposal.toDto().toJson()).toDomain();

      expect(back, proposal, reason: '$status');
      expect(back.song.album, 'Dobro jutro');
    }
  });

  test('Room krug za svako stanje sobe', () {
    for (final status in [
      const RoomOpen(),
      const RoomPaused(),
      const RoomClosed(),
    ]) {
      final room = const Room(
        id: RoomId('r1'),
        name: 'Zurka',
        hostId: UserId('u9'),
      ).withStatus(status);

      expect(RoomDto.fromJson(room.toDto().toJson()).toDomain(), room);
    }
  });

  test('User krug za svaku ulogu, blocked ne ide na mrezu', () {
    for (final role in Role.values) {
      final user = User(id: const UserId('u1'), displayName: 'Ana', role: role);
      final json = user.toDto().toJson();

      expect(json['role'], role.name);
      expect(json.keys, isNot(contains('blocked')));
      expect(UserDto.fromJson(json).toDomain(), user);
    }
  });

  test('Vote i Round krug', () {
    final vote = Vote(
      id: const VoteId('v1'),
      roundId: const RoundId('rd1'),
      proposalId: const ProposalId('p1'),
      voterId: const UserId('u1'),
      castAt: DateTime.utc(2026, 11, 20, 10, 5),
    );
    final round = Round(
      id: const RoundId('rd1'),
      roomId: const RoomId('r1'),
      startsAt: DateTime.utc(2026, 11, 20, 10),
      endsAt: DateTime.utc(2026, 11, 20, 10, 5),
    );

    expect(VoteDto.fromJson(vote.toDto().toJson()).toDomain(), vote);
    expect(RoundDto.fromJson(round.toDto().toJson()).toDomain(), round);
  });

  test('snimak sobe krug ima oblik porta RoomSnapshot', () {
    const room = Room(id: RoomId('r1'), name: 'Zurka', hostId: UserId('u9'));
    final round = Round(
      id: const RoundId('rd1'),
      roomId: const RoomId('r1'),
      startsAt: DateTime.utc(2026, 11, 20, 10),
      endsAt: DateTime.utc(2026, 11, 20, 10, 5),
    );
    final proposal = Proposal(
      id: const ProposalId('p1'),
      roomId: const RoomId('r1'),
      song: const Song(title: 'Fuego', artist: 'Severina'),
      proposedBy: const UserId('u1'),
      proposedAt: DateTime.utc(2026, 11, 20, 10, 1),
      status: const InVoting(),
    );

    final json = roomSnapshotToDto(
      room: room,
      round: round,
      proposals: [proposal],
      votes: const [],
    ).toJson();
    final back = RoomSnapshotDto.fromJson(json).toDomain();

    expect(back.room, room);
    expect(back.round, round);
    expect(back.proposals, [proposal]);
    expect(back.votes, isEmpty);
  });

  test('kodovi stanja i uloga: nepoznat kod daje null', () {
    expect(proposalStatusFromCode('leprsa'), isNull);
    expect(proposalStatusFromCode(ProposalStatusCodes.played), isNull);
    expect(roomStatusFromCode('srusena'), isNull);
    expect(roleFromCode('superadmin'), isNull);
  });

  test('rucno napravljen DTO sa nepoznatim kodom baca FormatException', () {
    expect(
      () => const RoomDto(
        id: 'r1',
        name: 'Z',
        hostId: 'u9',
        status: 'srusena',
      ).toDomain(),
      throwsFormatException,
    );
  });
}
