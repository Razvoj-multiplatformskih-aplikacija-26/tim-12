// Stanja predloga pesme (odluka O4: 6 stanja).
//
// Tok: predlozena → u glasanju → pobednik → pustena.
// Alternativni zavrseci: u glasanju → odbijena (izgubila rundu);
// bilo koje nezavrseno (predlozena, u glasanju, pobednik) → uklonjena
// (uklonio moderator ili host). Pustena, odbijena i uklonjena su terminalna.
//
// Sealed hijerarhija (a ne enum) da svako stanje moze kasnije da ponese
// svoje podatke bez lomljenja klijenta; kompajler tera da `switch` obradi
// svih 6 — zaboravljeno stanje je greska pre pokretanja, ne bag na odbrani.
sealed class ProposalStatus {
  const ProposalStatus();
}

/// Predlozena — ceka ulazak u glasanje.
final class Proposed extends ProposalStatus {
  const Proposed();
}

/// U glasanju — slusaoci glasaju u tekucoj rundi.
final class InVoting extends ProposalStatus {
  const InVoting();
}

/// Pobednik — proglasena za pobednika runde, ceka pustanje.
final class Winner extends ProposalStatus {
  const Winner();
}

/// Pustena — host je pustio pesmu. Terminalno.
final class Played extends ProposalStatus {
  const Played();
}

/// Odbijena — izgubila rundu. Terminalno.
final class Rejected extends ProposalStatus {
  const Rejected();
}

/// Uklonjena — uklonio moderator ili host. Terminalno.
final class Removed extends ProposalStatus {
  const Removed();
}

/// Jedina funkcija koja kaze koji su prelazi dozvoljeni.
///
/// Sva logika prelaza zivi ovde na jednom mestu: ekrani, Bloc i server
/// (KT2) samo je pitaju, pa se promena pravila prelaza vidi na jednom diffu.
bool canTransition(ProposalStatus from, ProposalStatus to) => switch ((from, to)) {
  (Proposed(), InVoting()) => true,
  (Proposed(), Removed()) => true,
  (InVoting(), Winner()) => true,
  (InVoting(), Rejected()) => true,
  (InVoting(), Removed()) => true,
  (Winner(), Played()) => true,
  (Winner(), Removed()) => true,
  _ => false,
};
