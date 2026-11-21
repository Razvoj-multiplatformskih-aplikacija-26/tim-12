// Kako stanja, uloge i vreme izgledaju na mrezi: obicni stringovi.
//
// Ugovor ne poznaje domenske tipove (`ProposalStatus`, `RoomStatus`, `Role`),
// zna samo dogovorene stringove. Prevod string <-> tip je u
// `packages/mapping`.

/// Stanja predloga na mrezi. `played` uvek ide uz `playedAt`.
abstract final class ProposalStatusCodes {
  static const proposed = 'proposed';
  static const inVoting = 'in_voting';
  static const winner = 'winner';
  static const played = 'played';
  static const rejected = 'rejected';
  static const removed = 'removed';

  static const all = {proposed, inVoting, winner, played, rejected, removed};
}

/// Stanja sobe na mrezi.
abstract final class RoomStatusCodes {
  static const open = 'open';
  static const paused = 'paused';
  static const closed = 'closed';

  static const all = {open, paused, closed};
}

/// Uloge na mrezi.
abstract final class RoleCodes {
  static const listener = 'listener';
  static const host = 'host';
  static const moderator = 'moderator';

  static const all = {listener, host, moderator};
}

/// Vreme na mrezi: ISO-8601 u UTC-u.
String wireTime(DateTime time) => time.toUtc().toIso8601String();
