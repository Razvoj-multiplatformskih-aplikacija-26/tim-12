// Korisnik sistema (slusalac, host ili moderator).
//
// Model nosi samo ono sto pravilima i prikazu treba: identifikator,
// prikazno ime, ulogu i da li je nalog blokiran. Kredencijali (lozinka,
// token) nisu domenski pojam — zive samo na serveru i u skladistu klijenta.
import 'ids.dart';
import 'role.dart';

final class User {
  const User({
    required this.id,
    required this.displayName,
    required this.role,
    this.blocked = false,
  });

  final UserId id;
  final String displayName;
  final Role role;

  /// Blokiran nalog ne sme nista sto menja podatke (vidi `checkAllowed`).
  final bool blocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          other.id == id &&
          other.displayName == displayName &&
          other.role == role &&
          other.blocked == blocked;

  @override
  int get hashCode => Object.hash(id, displayName, role, blocked);

  @override
  String toString() => 'User($displayName, ${role.name})';
}
