// DTO sobe, runde i snimka sobe — oblik odgovora za rute soba.
//
// Snimak sobe (`RoomSnapshotDto`) nosi sve sto ekranu glavnog toka treba:
// soba + tekuca runda + svi predlozi + glasovi tekuce runde. Prevod u
// domenske tipove (i u port `RoomSnapshot` iz `blocs`) je u
// `packages/mapping`.
import 'proposal_dto.dart';
import 'wire_codes.dart';

/// Soba kao odgovor servera.
final class RoomDto {
  const RoomDto({
    required this.id,
    required this.name,
    required this.hostId,
    required this.status,
  });

  final String id;
  final String name;
  final String hostId;

  /// Jedan od [RoomStatusCodes].
  final String status;

  factory RoomDto.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final hostId = json['hostId'];
    final status = json['status'];
    if (id is! String || name is! String || hostId is! String) {
      throw const FormatException('RoomDto trazi id/name/hostId');
    }
    if (status is! String || !RoomStatusCodes.all.contains(status)) {
      throw FormatException('RoomDto.status nepoznat: $status');
    }
    return RoomDto(id: id, name: name, hostId: hostId, status: status);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'hostId': hostId,
    'status': status,
  };
}

/// Lista soba: `{rooms: [...]}`.
final class RoomListResponse {
  const RoomListResponse({required this.rooms});

  final List<RoomDto> rooms;

  factory RoomListResponse.fromJson(Map<String, Object?> json) {
    final rooms = json['rooms'];
    if (rooms is! List) {
      throw const FormatException('RoomListResponse trazi rooms');
    }
    return RoomListResponse(
      rooms: [for (final room in rooms) RoomDto.fromJson(_map(room))],
    );
  }

  Map<String, Object?> toJson() => {
    'rooms': [for (final room in rooms) room.toJson()],
  };
}

/// Runda glasanja kao odgovor servera.
final class RoundDto {
  const RoundDto({
    required this.id,
    required this.roomId,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final String roomId;
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
    return RoundDto(id: id, roomId: roomId, startsAt: startsAt, endsAt: endsAt);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'roomId': roomId,
    'startsAt': wireTime(startsAt),
    'endsAt': wireTime(endsAt),
  };
}

/// Telo pravljenja sobe. Host je pozivalac — server ga zna iz tokena.
final class CreateRoomRequest {
  const CreateRoomRequest({required this.name});

  final String name;

  /// Baca [FormatException] kad `name` nije string (prazno ime je pravilo
  /// domena, ne format).
  factory CreateRoomRequest.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    if (name is! String) {
      throw const FormatException('CreateRoomRequest trazi name');
    }
    return CreateRoomRequest(name: name);
  }

  Map<String, Object?> toJson() => {'name': name};
}

/// Snimak sobe: sve sto ekranu glavnog toka treba, u jednom odgovoru.
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
    if (room is! Map || round is! Map || proposals is! List || votes is! List) {
      throw const FormatException(
        'RoomSnapshotDto trazi room/round/proposals/votes',
      );
    }
    return RoomSnapshotDto(
      room: RoomDto.fromJson(_map(room)),
      round: RoundDto.fromJson(_map(round)),
      proposals: [for (final p in proposals) ProposalDto.fromJson(_map(p))],
      votes: [for (final v in votes) VoteDto.fromJson(_map(v))],
    );
  }

  Map<String, Object?> toJson() => {
    'room': room.toJson(),
    'round': round.toJson(),
    'proposals': [for (final p in proposals) p.toJson()],
    'votes': [for (final v in votes) v.toJson()],
  };
}

/// JSON objekat u `Map<String, Object?>`; baca za sve sto nije objekat.
Map<String, Object?> _map(Object? json) {
  if (json is Map<String, Object?>) return json;
  if (json is Map) {
    return {for (final entry in json.entries) '${entry.key}': entry.value};
  }
  throw const FormatException('Ocekivan JSON objekat');
}
