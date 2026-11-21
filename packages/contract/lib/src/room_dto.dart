// DTO sobe, runde i snimka sobe — oblik odgovora za rute soba.
//
// Snimak sobe (`RoomSnapshotDto`) odgovara portu u `blocs`
// (`RoomSnapshot`): soba + tekuca runda + svi predlozi + glasovi tekuce
// runde. Prevod u domenske tipove je ovde, da HTTP sloj ne ponavlja oblik.
import 'package:radioroom_domain/radioroom_domain.dart';

import 'proposal_dto.dart';

/// Soba kao odgovor servera.
final class RoomDto {
  const RoomDto({
    required this.id,
    required this.name,
    required this.hostId,
    required this.status,
  });

  final RoomId id;
  final String name;
  final UserId hostId;
  final RoomStatus status;

  factory RoomDto.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final hostId = json['hostId'];
    final status = switch (json['status']) {
      'open' => const RoomOpen(),
      'paused' => const RoomPaused(),
      'closed' => const RoomClosed(),
      _ => null,
    };
    if (id is! String || name is! String || hostId is! String) {
      throw const FormatException('RoomDto trazi id/name/hostId');
    }
    if (status == null) {
      throw FormatException('RoomDto.status nepoznat: ${json['status']}');
    }
    return RoomDto(
      id: RoomId(id),
      name: name,
      hostId: UserId(hostId),
      status: status,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.value,
    'name': name,
    'hostId': hostId.value,
    'status': switch (status) {
      RoomOpen() => 'open',
      RoomPaused() => 'paused',
      RoomClosed() => 'closed',
    },
  };

  Room toDomain() => Room(id: id, name: name, hostId: hostId, status: status);

  factory RoomDto.fromDomain(Room room) => RoomDto(
    id: room.id,
    name: room.name,
    hostId: room.hostId,
    status: room.status,
  );
}

/// Runda glasanja kao odgovor servera.
final class RoundDto {
  const RoundDto({
    required this.id,
    required this.roomId,
    required this.startsAt,
    required this.endsAt,
  });

  final RoundId id;
  final RoomId roomId;
  final DateTime startsAt;
  final DateTime endsAt;

  factory RoundDto.fromJson(Map<String, Object?> json) {
    final startsAt = DateTime.tryParse('${json['startsAt']}');
    final endsAt = DateTime.tryParse('${json['endsAt']}');
    final id = json['id'];
    final roomId = json['roomId'];
    if (id is! String || roomId is! String) {
      throw const FormatException('RoundDto trazi id/roomId');
    }
    if (startsAt == null || endsAt == null) {
      throw const FormatException('RoundDto trazi startsAt/endsAt kao datume');
    }
    return RoundDto(
      id: RoundId(id),
      roomId: RoomId(roomId),
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.value,
    'roomId': roomId.value,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
  };

  Round toDomain() =>
      Round(id: id, roomId: roomId, startsAt: startsAt, endsAt: endsAt);

  factory RoundDto.fromDomain(Round round) => RoundDto(
    id: round.id,
    roomId: round.roomId,
    startsAt: round.startsAt,
    endsAt: round.endsAt,
  );
}

/// Telo pravljenja sobe. Host je pozivalac — server ga zna iz tokena.
final class CreateRoomRequest {
  const CreateRoomRequest({required this.name});

  final String name;

  Map<String, Object?> toJson() => {'name': name};
}

/// Snimak sobe: sve sto ekranu glavnog toka treba, u jednom odgovoru.
/// `toDomain` vraca zapis istog oblika kao port `RoomSnapshot` u `blocs`.
final class RoomSnapshotDto {
  const RoomSnapshotDto({
    required this.room,
    required this.round,
    required this.proposals,
    required this.votes,
  });

  final RoomDto room;
  final RoundDto round;
  final List<ProposalDto> proposals;
  final List<VoteDto> votes;

  factory RoomSnapshotDto.fromJson(Map<String, Object?> json) {
    final room = json['room'];
    final round = json['round'];
    final proposals = json['proposals'];
    final votes = json['votes'];
    if (room is! Map<String, Object?> ||
        round is! Map<String, Object?> ||
        proposals is! List ||
        votes is! List) {
      throw const FormatException(
        'RoomSnapshotDto trazi room/round/proposals/votes',
      );
    }
    return RoomSnapshotDto(
      room: RoomDto.fromJson(room),
      round: RoundDto.fromJson(round),
      proposals: [
        for (final p in proposals)
          if (p is Map<String, Object?>) ProposalDto.fromJson(p),
      ],
      votes: [
        for (final v in votes)
          if (v is Map<String, Object?>) VoteDto.fromJson(v),
      ],
    );
  }

  ({Room room, Round round, List<Proposal> proposals, List<Vote> votes})
  toDomain() => (
    room: room.toDomain(),
    round: round.toDomain(),
    proposals: [for (final p in proposals) p.toDomain()],
    votes: [for (final v in votes) v.toDomain()],
  );
}
