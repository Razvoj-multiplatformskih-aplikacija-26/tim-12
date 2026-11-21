// Prevod domenskih gresaka pravila u ugovor i nazad — jedno mesto.
//
// Pravila ostaju u `domain` (paket ih ne ponavlja): ovde se samo tip
// greske (`ProposalRuleError`) preslikava u `{code, data}` za server i
// nazad u tip za klijentov prikaz poruke na srpskom.
//
// Nepoznat kôd ili osteceni podaci ne ruse staru verziju: [ruleErrorFromApi]
// tada vrati `null`, a klijent pokaze opstu poruku umesto specificne.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'codes.dart';

/// Domenska greska u `{code, data}` za server: kôd i podaci, bez teksta.
/// HTTP status za kôd daje `ErrorCodes.httpStatus`.
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
      'playedAt': wireTime(playedAt),
    },
  ),
  InvalidVoteTarget(:final proposalId) => ApiError(
    code: ErrorCodes.invalidVoteTarget,
    data: {'proposalId': proposalId.value},
  ),
  // Pozivalac je uvek glasac, pa `voterId` ne ide na mrezu.
  AlreadyVotedInRound(:final roundId) => ApiError(
    code: ErrorCodes.alreadyVotedInRound,
    data: {'roundId': roundId.value},
  ),
  ProposalNotRemovable(:final proposalId) => ApiError(
    code: ErrorCodes.proposalNotRemovable,
    data: {'proposalId': proposalId.value},
  ),
  RoomNotClosable() => const ApiError(code: ErrorCodes.roomNotClosable),
  RoomNameEmpty() => const ApiError(code: ErrorCodes.roomNameEmpty),
  ActionNotAllowed(:final action, :final role) => ApiError(
    code: ErrorCodes.actionNotAllowed,
    data: {'action': action.name, 'role': roleToCode(role)},
  ),
  UserBlocked() => const ApiError(code: ErrorCodes.userBlocked),
  BackofficeNotAllowed(:final role) => ApiError(
    code: ErrorCodes.backofficeNotAllowed,
    data: {'role': roleToCode(role)},
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
    data: {'status': roomStatusToCode(status)},
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
      // Na mrezi je samo roundId (vidi gore); domenski tip trazi voterId,
      // a poruka ga ne koristi.
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
      final role = roleFromCode(data['role']);
      if (action == null || role == null) return null;
      return ActionNotAllowed(action: action, role: role);
    case ErrorCodes.userBlocked:
      return const UserBlocked();
    case ErrorCodes.backofficeNotAllowed:
      final role = roleFromCode(data['role']);
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
      final status = roomStatusFromCode(data['status']);
      return status == null ? null : RoomNotOpen(status: status);
    case ErrorCodes.roundClosed:
      final roundId = _id(data, 'roundId');
      return roundId == null ? null : RoundClosed(roundId: RoundId(roundId));
    default:
      return null;
  }
}

/// Neprazan string-ID iz `data`, ili `null` kad ga nema.
String? _id(Map<String, Object?> data, String key) {
  final value = data[key];
  return value is String && value.isNotEmpty ? value : null;
}
