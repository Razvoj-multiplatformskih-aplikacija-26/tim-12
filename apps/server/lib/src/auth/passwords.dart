// Hesiranje lozinki — jedino mesto gde server dodiruje lozinku.
//
// bcrypt (spec dozvoljava Argon2id, bcrypt, scrypt ili PBKDF2): so i cena
// su upisani u sam hes (`$2a$10$...`), pa baza cuva jedan string po
// korisniku. Odbaceno: PBKDF2 — na preporucenih 600k iteracija prijava je
// u cistom Dartu trajala 1–3 s (mereno), a paket `crypto` ga nema.
import 'package:bcrypt/bcrypt.dart';

final class PasswordHasher {
  /// [cost] je log2 broja rundi: 10 je preporuceni minimum (~110 ms po
  /// proveri na razvojnom racunaru). Testovi koriste nizu cenu zbog brzine.
  const PasswordHasher({this.cost = 10});

  final int cost;

  /// Novi hes sa novom slucajnom soli — ista lozinka daje razlicite hesove.
  String hash(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt(logRounds: cost));

  /// Da li [password] odgovara [hash]. Neispravan zapis hesa je "ne
  /// odgovara", a ne izuzetak koji bi oborio zahtev.
  bool verify(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } on Object {
      return false;
    }
  }
}
