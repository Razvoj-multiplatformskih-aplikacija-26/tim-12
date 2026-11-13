// Uloga korisnika (KT2: prijava i prava).
//
// Enum, a ne sealed hijerarhija: uloge ne nose podatke. Sta koja uloga sme
// ne pise ovde nego u `rules/permissions.dart` — jedno mesto za prava.
enum Role {
  /// Slusalac — predlaze i glasa (mobilna aplikacija).
  listener,

  /// Host/DJ — otvara sobu, predlaze i glasa (mobilna aplikacija).
  host,

  /// Moderator — uklanja predloge, zatvara sobe, blokira naloge (backoffice).
  moderator,
}
