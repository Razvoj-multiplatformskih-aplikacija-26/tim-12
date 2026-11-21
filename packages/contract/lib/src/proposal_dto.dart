// DTO predloga i glasa — telo zahteva i oblik odgovora za rute predloga.
//
// Pesma putuje ugnjezdena (`song: {title, artist, externalLink?}`), stanje
// predloga kao string sa opcionim `playedAt`. Vremena su ISO-8601 (UTC).
import 'package:radioroom_domain/radioroom_domain.dart';

/// Predlog kao odgovor servera.
final class ProposalDto {
  const ProposalDto({
    required this.id,
    required this.roomId,
    required this.title,
    required this.artist,
    this.externalLink,
    required this.proposedBy,
    required this.proposedAt,
    required this.status,
  });

  final ProposalId id;
  final RoomId roomId;
  final String title;
  final String artist;
  final String? externalLink;
  final UserId proposedBy;
  final DateTime proposedAt;
  final ProposalStatus status;

  factory ProposalDto.fromJson(Map<String, Object?> json) {
    final song = json['song'];
    final playedAt = DateTime.tryParse('${json['playedAt']}');
    final status = _statusFromJson(json['status'], playedAt);
    final proposedAt = DateTime.tryParse('${json['proposedAt']}');
    final id = json['id'];
    final roomId = json['roomId'];
    final proposedBy = json['proposedBy'];
    if (song is! Map<String, Object?> ||
        song['title'] is! String ||
        song['artist'] is! String) {
      throw const FormatException('ProposalDto.song mora imati title/artist');
    }
    if (id is! String || roomId is! String || proposedBy is! String) {
      throw const FormatException('ProposalDto trazi id/roomId/proposedBy');
    }
    if (proposedAt == null) {
      throw FormatException(
        'ProposalDto.proposedAt nije datum: ${json['proposedAt']}',
      );
    }
    if (status == null) {
      throw FormatException('ProposalDto.status nepoznat: ${json['status']}');
    }
    final externalLink = song['externalLink'];
    return ProposalDto(
      id: ProposalId(id),
      roomId: RoomId(roomId),
      title: song['title'] as String,
      artist: song['artist'] as String,
      externalLink: externalLink is String ? externalLink : null,
      proposedBy: UserId(proposedBy),
      proposedAt: proposedAt,
      status: status,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.value,
    'roomId': roomId.value,
    'song': {
      'title': title,
      'artist': artist,
      if (externalLink != null) 'externalLink': externalLink,
    },
    'proposedBy': proposedBy.value,
    'proposedAt': proposedAt.toIso8601String(),
    'status': _statusToJson(status),
    if (status case Played(playedAt: final at))
      'playedAt': at.toIso8601String(),
  };

  Proposal toDomain() => Proposal(
    id: id,
    roomId: roomId,
    song: Song(title: title, artist: artist, externalLink: externalLink),
    proposedBy: proposedBy,
    proposedAt: proposedAt,
    status: status,
  );

  factory ProposalDto.fromDomain(Proposal proposal) => ProposalDto(
    id: proposal.id,
    roomId: proposal.roomId,
    title: proposal.song.title,
    artist: proposal.song.artist,
    externalLink: proposal.song.externalLink,
    proposedBy: proposal.proposedBy,
    proposedAt: proposal.proposedAt,
    status: proposal.status,
  );
}

/// Telo predlaganja pesme. Identitet predlagaca se ne salje — server ga
/// zna iz tokena. `roomId` putuje i u telu i (po dogovoru) u putanji rute.
final class CreateProposalRequest {
  const CreateProposalRequest({
    required this.roomId,
    required this.title,
    required this.artist,
    this.externalLink,
  });

  final RoomId roomId;
  final String title;
  final String artist;
  final String? externalLink;

  Map<String, Object?> toJson() => {
    'roomId': roomId.value,
    'song': {
      'title': title,
      'artist': artist,
      if (externalLink != null) 'externalLink': externalLink,
    },
  };
}

/// Glas kao odgovor servera. ID i trenutak dodeljuje server.
final class VoteDto {
  const VoteDto({
    required this.id,
    required this.roundId,
    required this.proposalId,
    required this.voterId,
    required this.castAt,
  });

  final VoteId id;
  final RoundId roundId;
  final ProposalId proposalId;
  final UserId voterId;
  final DateTime castAt;

  factory VoteDto.fromJson(Map<String, Object?> json) {
    final castAt = DateTime.tryParse('${json['castAt']}');
    final id = json['id'];
    final roundId = json['roundId'];
    final proposalId = json['proposalId'];
    final voterId = json['voterId'];
    if (id is! String ||
        roundId is! String ||
        proposalId is! String ||
        voterId is! String) {
      throw const FormatException('VoteDto trazi id/roundId/proposalId/voterId');
    }
    if (castAt == null) {
      throw FormatException('VoteDto.castAt nije datum: ${json['castAt']}');
    }
    return VoteDto(
      id: VoteId(id),
      roundId: RoundId(roundId),
      proposalId: ProposalId(proposalId),
      voterId: UserId(voterId),
      castAt: castAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.value,
    'roundId': roundId.value,
    'proposalId': proposalId.value,
    'voterId': voterId.value,
    'castAt': castAt.toIso8601String(),
  };

  Vote toDomain() => Vote(
    id: id,
    roundId: roundId,
    proposalId: proposalId,
    voterId: voterId,
    castAt: castAt,
  );

  factory VoteDto.fromDomain(Vote vote) => VoteDto(
    id: vote.id,
    roundId: vote.roundId,
    proposalId: vote.proposalId,
    voterId: vote.voterId,
    castAt: vote.castAt,
  );
}

/// Telo glasanja. Rundu klijent zna iz snimka sobe; glasača server zna
/// iz tokena, pa se `voterId` ne salje.
final class CastVoteRequest {
  const CastVoteRequest({required this.roundId, required this.proposalId});

  final RoundId roundId;
  final ProposalId proposalId;

  Map<String, Object?> toJson() => {
    'roundId': roundId.value,
    'proposalId': proposalId.value,
  };
}

ProposalStatus? _statusFromJson(Object? status, DateTime? playedAt) =>
    switch (status) {
      'proposed' => const Proposed(),
      'in_voting' => const InVoting(),
      'winner' => const Winner(),
      'played' => playedAt == null ? null : Played(playedAt),
      'rejected' => const Rejected(),
      'removed' => const Removed(),
      _ => null,
    };

String _statusToJson(ProposalStatus status) => switch (status) {
  Proposed() => 'proposed',
  InVoting() => 'in_voting',
  Winner() => 'winner',
  Played() => 'played',
  Rejected() => 'rejected',
  Removed() => 'removed',
};
