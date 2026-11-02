// Korisnik sistema (slusalac, host ili moderator).
//
// U KT1 nema prijave: aplikacije rade kao jedan korisnik, pa model nosi
// samo ono sto pravilima i prikazu treba — identifikator i prikazno ime.
// Uloga i kredencijali stizu tek u KT2.
import 'ids.dart';

final class User {
  const User({required this.id, required this.displayName});

  final UserId id;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && other.id == id && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);

  @override
  String toString() => 'User($displayName)';
}
