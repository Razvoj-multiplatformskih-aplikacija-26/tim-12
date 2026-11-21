// Prevod domenskih gresaka pravila u ugovor i nazad — jedno mesto.
//
// Pravila ostaju u `domain` (paket ih ne ponavlja): ovde se samo tip
// greske (`ProposalRuleError`) preslikava u `{code, data}` za server i
// nazad u tip za klijentov prikaz poruke na srpskom.
//
// Nepoznat kôd ili osteceni podaci ne ruse staru verziju: [ruleErrorFromApi]
// tada vrati `null`, a klijent pokaze opstu poruku umesto specificne.
import 'package:radioroom_domain/radioroom_domain.dart';

import 'api_error.dart';

/// Domenska greska u `{code, data}` za server (isti oblik kao `errorResponse`
/// u `apps/server`: kôd i podaci, bez teksta).
ApiError apiErrorFromRule(ProposalRuleError error) => switch (error) {
  TooManyActiveProposals(:final activeCount, :final limit) => ApiError(
    code: ErrorCodes.tooManyActiveProposals,
    data: {'activeCount': activeCount, 'limit': limit},
  ),
  RecentlyPlayedSong(:final song, :final playedAt) => ApiError(
    code: ErrorCodes.recentlyPlayedSong,
    data: {
      'title': song.title,
      'artist': song.artist,
      'playedAt': playedAt.toIso8601String(),
    },
  ),
  InvalidVoteTarget(:final proposalId) => ApiError(
    code: ErrorCodes.invalidVoteTarget,
    data: {'proposalId': proposalId.value},
  ),
  AlreadyVotedInRound(:final voterId, :final roundId) => ApiError(
    code: ErrorCodes.alreadyVotedInRound,
    data: {'voterId': voterId.value, 'roundId': roundId.value},
  ),
  ProposalNotRemovable(:final proposalId) => ApiError(
    code: ErrorCodes.proposalNotRemovable,
    data: {'proposalId': proposalId.value},
  ),
  RoomNotClosable() => const ApiError(code: ErrorCodes.roomNotClosable),
  RoomNameEmpty() => const ApiError(code: ErrorCodes.roomNameEmpty),
  ActionNotAllowed(:final action, :final role) => ApiError(
    code: ErrorCodes.actionNotAllowed,
    data: {'action': action.name, 'role': role.name},
  ),
  UserBlocked() => const ApiError(code: ErrorCodes.userBlocked),
  BackofficeNotAllowed(:final role) => ApiError(
    code: ErrorCodes.backofficeNotAllowed,
    data: {'role': role.name},
  ),
  NotOwnProposal(:final proposalId) => ApiError(
    code: ErrorCodes.notOwnProposal,
    data: {'proposalId': proposalId.value},
  ),
  ProposalNotWithdrawable(:final proposalId) => ApiError(
    code: ErrorCodes.proposalNotWithdrawable,
    data: {'proposalId': proposalId.value},
  ),
  RoomNotOpen(:final status) => ApiError(
    code: ErrorCodes.roomNotOpen,
    data: {'status': _roomStatusToCode(status)},
  ),
  RoundClosed(:final roundId) => ApiError(
    code: ErrorCodes.roundClosed,
    data: {'roundId': roundId.value},
  ),
};

/// Tip greske iz `{code, data}` za prikaz poruke. `null` znaci: nepoznat kôd
/// ili osteceni podaci — pozivalac tada koristi opstu poruku, ne pada.
ProposalRuleError? ruleErrorFromApi(ApiError error) {
  final data = error.data;
  switch (error.code) {
    case ErrorCodes.tooManyActiveProposals:
      final activeCount = data['activeCount'];
      final limit = data['limit'];
      if (activeCount is! int || limit is! int) return null;
      return TooManyActiveProposals(activeCount: activeCount, limit: limit);
    case ErrorCodes.recentlyPlayedSong:
      final title = data['title'];
      final artist = data['artist'];
      final playedAt = DateTime.tryParse('${data['playedAt']}');
      if (title is! String || artist is! String || playedAt == null) {
        return null;
      }
      return RecentlyPlayedSong(
        song: Song(title: title, artist: artist),
        playedAt: playedAt,
      );
    case ErrorCodes.invalidVoteTarget:
      final proposalId = _id(data, 'proposalId');
      return proposalId == null
          ? null
          : InvalidVoteTarget(proposalId: ProposalId(proposalId));
    case ErrorCodes.alreadyVotedInRound:
      // Server salje samo roundId (pozivalac je uvek glasac, pa voterId
      // ne ide na mrezu); domenski tip ga zahteva, a poruka ga ne koristi.
      final voterId = _id(data, 'voterId') ?? '';
      final roundId = _id(data, 'roundId');
      if (roundId == null) return null;
      return AlreadyVotedInRound(
        voterId: UserId(voterId),
        roundId: RoundId(roundId),
      );
    case ErrorCodes.proposalNotRemovable:
      final proposalId = _id(data, 'proposalId');
      return proposalId == null
          ? null
          : ProposalNotRemovable(proposalId: ProposalId(proposalId));
    case ErrorCodes.roomNotClosable:
      return const RoomNotClosable();
    case ErrorCodes.roomNameEmpty:
      return const RoomNameEmpty();
    case ErrorCodes.actionNotAllowed:
      final action = UserAction.values.asNameMap()[data['action']];
      final role = Role.values.asNameMap()[data['role']];
      if (action == null || role == null) return null;
      return ActionNotAllowed(action: action, role: role);
    case ErrorCodes.userBlocked:
      return const UserBlocked();
    case ErrorCodes.backofficeNotAllowed:
      final role = Role.values.asNameMap()[data['role']];
      if (role == null) return null;
      return BackofficeNotAllowed(role: role);
    case ErrorCodes.notOwnProposal:
      final proposalId = _id(data, 'proposalId');
      return proposalId == null
          ? null
          : NotOwnProposal(proposalId: ProposalId(proposalId));
    case ErrorCodes.proposalNotWithdrawable:
      final proposalId = _id(data, 'proposalId');
      return proposalId == null
          ? null
          : ProposalNotWithdrawable(proposalId: ProposalId(proposalId));
    case ErrorCodes.roomNotOpen:
      final status = _roomStatusFromCode(data['status']);
      return status == null ? null : RoomNotOpen(status: status);
    case ErrorCodes.roundClosed:
      final roundId = _id(data, 'roundId');
      return roundId == null
          ? null
          : RoundClosed(roundId: RoundId(roundId));
    default:
      return null;
  }
}

/// Neprazan string-ID iz `data`, ili `null` kad ga nema.
String? _id(Map<String, Object?> data, String key) {
  final value = data[key];
  return value is String && value.isNotEmpty ? value : null;
}

/// Kod stanja sobe u tip (`open`/`paused`/`closed`); `null` za nepoznato.
RoomStatus? _roomStatusFromCode(Object? code) => switch (code) {
  'open' => const RoomOpen(),
  'paused' => const RoomPaused(),
  'closed' => const RoomClosed(),
  _ => null,
};

/// Tip stanja sobe u kod za `{code, data}` (isti kodovi kao server).
String _roomStatusToCode(RoomStatus status) => switch (status) {
  RoomOpen() => 'open',
  RoomPaused() => 'paused',
  RoomClosed() => 'closed',
};
