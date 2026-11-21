// DTO pesme, predloga i glasa — telo zahteva i oblik odgovora za rute
// predloga i kataloga.
//
// Pesma putuje ugnjezdena (`song: {title, artist, ...}`), stanje predloga
// kao string iz [ProposalStatusCodes] sa `playedAt` uz `played`. ID-jevi su
// obicni stringovi, vremena ISO-8601 (UTC). Prevod u domenske tipove je u
// `packages/mapping`.
import 'wire_codes.dart';

/// Pesma na mrezi. Opciona polja se ne salju kad ih nema.
final class SongDto {
  const SongDto({
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.externalLink,
    this.coverUrl,
  });

  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? externalLink;
  final String? coverUrl;

  /// Opciono polje moze da izostane ili bude `null`; pogresan tip je
  /// [FormatException], ne tiho izostavljeno polje.
  factory SongDto.fromJson(Object? json) {
    if (json is! Map || json['title'] is! String || json['artist'] is! String) {
      throw const FormatException('SongDto mora imati title/artist');
    }
    return SongDto(
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: _optional<String>(json, 'album'),
      durationMs: _optional<int>(json, 'durationMs'),
      externalLink: _optional<String>(json, 'externalLink'),
      coverUrl: _optional<String>(json, 'coverUrl'),
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'artist': artist,
    if (album != null) 'album': album,
    if (durationMs != null) 'durationMs': durationMs,
    if (externalLink != null) 'externalLink': externalLink,
    if (coverUrl != null) 'coverUrl': coverUrl,
  };
}

/// Predlog kao odgovor servera.
final class ProposalDto {
  const ProposalDto({
    required this.id,
    required this.roomId,
    required this.song,
    required this.proposedBy,
    required this.proposedAt,
    required this.status,
    this.playedAt,
  });

  final String id;
  final String roomId;
  final SongDto song;
  final String proposedBy;
  final DateTime proposedAt;

  /// Jedan od [ProposalStatusCodes].
  final String status;

  /// Postoji tacno kad je [status] `played`.
  final DateTime? playedAt;

  factory ProposalDto.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final roomId = json['roomId'];
    final proposedBy = json['proposedBy'];
    final proposedAt = DateTime.tryParse('${json['proposedAt']}');
    final status = json['status'];
    final playedAt = DateTime.tryParse('${json['playedAt']}');
    if (id is! String || roomId is! String || proposedBy is! String) {
      throw const FormatException('ProposalDto trazi id/roomId/proposedBy');
    }
    if (proposedAt == null) {
      throw FormatException(
        'ProposalDto.proposedAt nije datum: ${json['proposedAt']}',
      );
    }
    if (status is! String || !ProposalStatusCodes.all.contains(status)) {
      throw FormatException('ProposalDto.status nepoznat: $status');
    }
    if (status == ProposalStatusCodes.played && playedAt == null) {
      throw const FormatException('ProposalDto: played trazi playedAt');
    }
    return ProposalDto(
      id: id,
      roomId: roomId,
      song: SongDto.fromJson(json['song']),
      proposedBy: proposedBy,
      proposedAt: proposedAt,
      status: status,
      playedAt: status == ProposalStatusCodes.played ? playedAt : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'roomId': roomId,
    'song': song.toJson(),
    'proposedBy': proposedBy,
    'proposedAt': wireTime(proposedAt),
    'status': status,
    if (playedAt case final at?) 'playedAt': wireTime(at),
  };
}

/// Telo predlaganja pesme. Identitet predlagaca se ne salje — server ga
/// zna iz tokena, a sobu iz putanje rute.
final class CreateProposalRequest {
  const CreateProposalRequest({required this.song});

  final SongDto song;

  factory CreateProposalRequest.fromJson(Map<String, Object?> json) =>
      CreateProposalRequest(song: SongDto.fromJson(json['song']));

  Map<String, Object?> toJson() => {'song': song.toJson()};
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

  final String id;
  final String roundId;
  final String proposalId;
  final String voterId;
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
      throw const FormatException(
        'VoteDto trazi id/roundId/proposalId/voterId',
      );
    }
    if (castAt == null) {
      throw FormatException('VoteDto.castAt nije datum: ${json['castAt']}');
    }
    return VoteDto(
      id: id,
      roundId: roundId,
      proposalId: proposalId,
      voterId: voterId,
      castAt: castAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'roundId': roundId,
    'proposalId': proposalId,
    'voterId': voterId,
    'castAt': wireTime(castAt),
  };
}

/// Telo glasanja. Rundu klijent zna iz snimka sobe; glasaca server zna
/// iz tokena, pa se `voterId` ne salje.
final class CastVoteRequest {
  const CastVoteRequest({required this.roundId, required this.proposalId});

  final String roundId;
  final String proposalId;

  /// Baca [FormatException] kad nedostaje runda ili predlog.
  factory CastVoteRequest.fromJson(Map<String, Object?> json) {
    final roundId = json['roundId'];
    final proposalId = json['proposalId'];
    if (roundId is! String ||
        roundId.isEmpty ||
        proposalId is! String ||
        proposalId.isEmpty) {
      throw const FormatException('CastVoteRequest trazi roundId/proposalId');
    }
    return CastVoteRequest(roundId: roundId, proposalId: proposalId);
  }

  Map<String, Object?> toJson() => {
    'roundId': roundId,
    'proposalId': proposalId,
  };
}

/// Odgovor pretrage kataloga: `{songs: [...]}`.
final class CatalogSearchResponse {
  const CatalogSearchResponse({required this.songs});

  final List<SongDto> songs;

  factory CatalogSearchResponse.fromJson(Map<String, Object?> json) {
    final songs = json['songs'];
    if (songs is! List) {
      throw const FormatException('CatalogSearchResponse trazi songs');
    }
    return CatalogSearchResponse(songs: songs.map(SongDto.fromJson).toList());
  }

  Map<String, Object?> toJson() => {
    'songs': [for (final song in songs) song.toJson()],
  };
}

/// Opciono polje [key] tipa [T]; baca kad postoji, a pogresnog je tipa.
T? _optional<T extends Object>(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is T) return value as T?;
  throw FormatException('SongDto.$key ima pogresan tip');
}
