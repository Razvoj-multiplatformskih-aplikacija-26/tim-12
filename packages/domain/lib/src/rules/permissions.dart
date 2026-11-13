// Prava: ko sme koju akciju — jedno mesto za klijente i server.
//
// Mobilna aplikacija i backoffice ga pitaju da sakriju ili onemoguce
// akciju, a server ga pita pre svakog upisa i odbija poziv mimo aplikacije
// istom greskom. Promena prava je izmena jednog reda u [allowedRoles].
//
// Greske su iste vrste kao kod ostalih pravila (`RuleOutcome`), pa ih
// klijent prikazuje istim putem (`ruleMessage`).
import '../models/proposal.dart';
import '../models/role.dart';
import '../models/user.dart';
import 'proposal_rules.dart';

/// Akcije koje menjaju podatke. Pregled (citanje) nije ovde: citanje je
/// dozvoljeno svakom prijavljenom korisniku.
enum UserAction {
  propose,
  vote,

  /// Slusalac povlaci SVOJ predlog (vidi [checkCanWithdraw]).
  withdrawProposal,
  createRoom,
  removeProposal,
  closeRoom,
  blockUser,
}

/// Uloge koje smeju [action]. Moderatorske akcije su samo u backoffice-u;
/// odluka para: host u KT2 ne uklanja tudje predloge ni u svojoj sobi
/// (njegova prava u sobi stizu sa host funkcijama u KT3).
Set<Role> allowedRoles(UserAction action) => switch (action) {
      UserAction.propose ||
      UserAction.vote ||
      UserAction.withdrawProposal =>
        const {Role.listener, Role.host},
      UserAction.createRoom => const {Role.host},
      UserAction.removeProposal ||
      UserAction.closeRoom ||
      UserAction.blockUser =>
        const {Role.moderator},
    };

/// Sme li [user] akciju [action]: blokiran nalog ne sme nista, a ostali
/// samo ono sto njihova uloga sme.
RuleOutcome checkAllowed({required User user, required UserAction action}) {
  if (user.blocked) return const RuleInvalid(UserBlocked());
  if (!allowedRoles(action).contains(user.role)) {
    return RuleInvalid(ActionNotAllowed(action: action, role: user.role));
  }
  return const RuleValid();
}

/// Prijava u backoffice: samo moderator koji nije blokiran.
RuleOutcome checkCanUseBackoffice({required User user}) {
  if (user.role != Role.moderator) {
    return RuleInvalid(BackofficeNotAllowed(role: user.role));
  }
  if (user.blocked) return const RuleInvalid(UserBlocked());
  return const RuleValid();
}

/// Povlacenje predloga: uloga sme, predlog je njegov i jos ceka ishod.
/// Redosled provera je redosled razloga koje korisnik vidi.
RuleOutcome checkCanWithdraw({
  required User user,
  required Proposal proposal,
}) {
  final allowed = checkAllowed(user: user, action: UserAction.withdrawProposal);
  if (!allowed.isValid) return allowed;
  if (proposal.proposedBy != user.id) {
    return RuleInvalid(NotOwnProposal(proposalId: proposal.id));
  }
  if (!proposal.isActive) {
    return RuleInvalid(ProposalNotWithdrawable(proposalId: proposal.id));
  }
  return const RuleValid();
}
