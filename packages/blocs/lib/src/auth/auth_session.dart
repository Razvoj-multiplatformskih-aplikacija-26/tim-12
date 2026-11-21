// Sesija iz uspesne prijave: korisnik za prikaz, token za zaglavlje i rok.
//
// Klijent nikad ne salje `userId` kao identitet: server zna ko poziva samo
// iz tokena u `Authorization` zaglavlju. Vreme roka injektuje server
// svojim satom — klijent ga samo nosi, ne racuna.
import 'package:radioroom_domain/radioroom_domain.dart';

/// Odgovor `POST /auth/login` kao domen: token putuje u skladiste, lozinka
/// se nigde ne cuva.
final class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  /// Prijavljeni korisnik — iz odgovora servera, nikad iz unosa klijenta.
  final User user;

  /// Token prijave; svaki sledeci poziv ga nosi u `Authorization` zaglavlju.
  final String token;

  /// Rok vazenja prijave.
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          other.user == user &&
          other.token == token &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(user, token, expiresAt);

  @override
  String toString() => 'AuthSession(${user.id}, $expiresAt)';
}
