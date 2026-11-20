// Prekrsaj domenskog pravila → HTTP odgovor `{code, data}`.
//
// Jedino mesto na serveru gde tip greske iz domena postaje kod na mrezi.
// Kod i podaci su isti kao oni koje bi klijent dobio da je pravilo sam
// proverio, pa poruku pravi klijent (`ruleMessage`) — server ne salje tekst.
// Exhaustive switch: novo pravilo u domenu je greska kompajliranja ovde dok
// mu se ne da kod. Privremeno u serveru; seli se u `packages/mapping`.
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:relic/relic.dart';

import '../rooms/room_store.dart' show roomStatusCode;
import 'json.dart';

/// Odgovor za prekrsaj pravila: 403 za prava, 409 za vec upisan glas,
/// 422 za ostala pravila.
Response ruleErrorResponse(ProposalRuleError error) {
  final (status, code, data) = ruleErrorWire(error);
  return errorResponse(status, code, data);
}

/// HTTP status, kod i podaci pravila za [error].
(int, String, Map<String, Object?>) ruleErrorWire(ProposalRuleError error) =>
    switch (error) {
      TooManyActiveProposals(:final activeCount, :final limit) => (
        422,
        'too_many_active_proposals',
        {'activeCount': activeCount, 'limit': limit},
      ),
      RecentlyPlayedSong(:final song, :final playedAt) => (
        422,
        'recently_played_song',
        {
          'title': song.title,
          'artist': song.artist,
          'playedAt': playedAt.toUtc().toIso8601String(),
        },
      ),
      InvalidVoteTarget(:final proposalId) => (
        422,
        'invalid_vote_target',
        {'proposalId': proposalId.value},
      ),
      AlreadyVotedInRound(:final roundId) => (
        409,
        'already_voted_in_round',
        {'roundId': roundId.value},
      ),
      ProposalNotRemovable(:final proposalId) => (
        422,
        'proposal_not_removable',
        {'proposalId': proposalId.value},
      ),
      RoomNotClosable() => (422, 'room_not_closable', {}),
      RoomNameEmpty() => (422, 'room_name_empty', {}),
      ActionNotAllowed(:final action, :final role) => (
        403,
        'action_not_allowed',
        {'action': action.name, 'role': role.name},
      ),
      UserBlocked() => (403, 'user_blocked', {}),
      BackofficeNotAllowed(:final role) => (
        403,
        'backoffice_not_allowed',
        {'role': role.name},
      ),
      NotOwnProposal(:final proposalId) => (
        403,
        'not_own_proposal',
        {'proposalId': proposalId.value},
      ),
      ProposalNotWithdrawable(:final proposalId) => (
        422,
        'proposal_not_withdrawable',
        {'proposalId': proposalId.value},
      ),
      RoomNotOpen(:final status) => (
        422,
        'room_not_open',
        {'status': roomStatusCode(status)},
      ),
      RoundClosed(:final roundId) => (
        422,
        'round_closed',
        {'roundId': roundId.value},
      ),
    };

/// Prvi prekrsaj iz niza provera, redom kojim korisnik treba da ih vidi.
ProposalRuleError? firstViolation(Iterable<RuleOutcome> outcomes) {
  for (final outcome in outcomes) {
    if (outcome.error case final error?) return error;
  }
  return null;
}
