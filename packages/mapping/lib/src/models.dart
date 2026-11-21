// Modeli: domen <-> DTO, kao ekstenzije (`proposal.toDto()`,
// `dto.toDomain()`), da pozivi u klijentima i na serveru ostanu kratki.
//
// DTO je vec proverio format pri `fromJson`, pa `toDomain` baca
// [FormatException] samo kad neko rucno napravi DTO sa nepoznatim kodom.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'codes.dart';

extension SongToDto on Song {
  SongDto toDto() => SongDto(
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    externalLink: externalLink,
    coverUrl: coverUrl,
  );
}

extension SongDtoToDomain on SongDto {
  Song toDomain() => Song(
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    externalLink: externalLink,
    coverUrl: coverUrl,
  );
}

extension ProposalToDto on Proposal {
  ProposalDto toDto() => ProposalDto(
    id: id.value,
    roomId: roomId.value,
    song: song.toDto(),
    proposedBy: proposedBy.value,
    proposedAt: proposedAt,
    status: proposalStatusToCode(status),
    playedAt: switch (status) {
      Played(:final playedAt) => playedAt,
      _ => null,
    },
  );
}

extension ProposalDtoToDomain on ProposalDto {
  Proposal toDomain() => Proposal(
    id: ProposalId(id),
    roomId: RoomId(roomId),
    song: song.toDomain(),
    proposedBy: UserId(proposedBy),
    proposedAt: proposedAt,
    status:
        proposalStatusFromCode(status, playedAt: playedAt) ??
        (throw FormatException('Nepoznato stanje predloga: $status')),
  );
}

extension VoteToDto on Vote {
  VoteDto toDto() => VoteDto(
    id: id.value,
    roundId: roundId.value,
    proposalId: proposalId.value,
    voterId: voterId.value,
    castAt: castAt,
  );
}

extension VoteDtoToDomain on VoteDto {
  Vote toDomain() => Vote(
    id: VoteId(id),
    roundId: RoundId(roundId),
    proposalId: ProposalId(proposalId),
    voterId: UserId(voterId),
    castAt: castAt,
  );
}

extension RoomToDto on Room {
  RoomDto toDto() => RoomDto(
    id: id.value,
    name: name,
    hostId: hostId.value,
    status: roomStatusToCode(status),
  );
}

extension RoomDtoToDomain on RoomDto {
  Room toDomain() => Room(
    id: RoomId(id),
    name: name,
    hostId: UserId(hostId),
    status:
        roomStatusFromCode(status) ??
        (throw FormatException('Nepoznato stanje sobe: $status')),
  );
}

extension RoundToDto on Round {
  RoundDto toDto() => RoundDto(
    id: id.value,
    roomId: roomId.value,
    startsAt: startsAt,
    endsAt: endsAt,
  );
}

extension RoundDtoToDomain on RoundDto {
  Round toDomain() => Round(
    id: RoundId(id),
    roomId: RoomId(roomId),
    startsAt: startsAt,
    endsAt: endsAt,
  );
}

extension UserToDto on User {
  /// `blocked` se ne salje (vidi [UserDto]).
  UserDto toDto() =>
      UserDto(id: id.value, displayName: displayName, role: roleToCode(role));
}

extension UserDtoToDomain on UserDto {
  User toDomain() => User(
    id: UserId(id),
    displayName: displayName,
    role:
        roleFromCode(role) ?? (throw FormatException('Nepoznata uloga: $role')),
    blocked: blocked,
  );
}

/// Snimak sobe u domenu — isti oblik kao port `RoomSnapshot` u `blocs`.
typedef RoomSnapshotRecord = ({
  Room room,
  Round round,
  List<Proposal> proposals,
  List<Vote> votes,
});

extension RoomSnapshotDtoToDomain on RoomSnapshotDto {
  RoomSnapshotRecord toDomain() => (
    room: room.toDomain(),
    round: round.toDomain(),
    proposals: [for (final p in proposals) p.toDomain()],
    votes: [for (final v in votes) v.toDomain()],
  );
}

/// Snimak sobe iz domena u DTO (server ga salje na `GET /rooms/:id`).
RoomSnapshotDto roomSnapshotToDto({
  required Room room,
  required Round round,
  required Iterable<Proposal> proposals,
  required Iterable<Vote> votes,
}) => RoomSnapshotDto(
  room: room.toDto(),
  round: round.toDto(),
  proposals: [for (final p in proposals) p.toDto()],
  votes: [for (final v in votes) v.toDto()],
);
