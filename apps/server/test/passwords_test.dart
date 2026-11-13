import 'package:radioroom_server/radioroom_server.dart';
import 'package:test/test.dart';

void main() {
  // Niska cena samo zbog brzine testa; server koristi podrazumevanu (10).
  const hasher = PasswordHasher(cost: 4);

  test('hes nije lozinka i prolazi proveru samo sa tacnom lozinkom', () {
    final hash = hasher.hash('demo1234');

    expect(hash, isNot(contains('demo1234')));
    expect(hasher.verify('demo1234', hash), isTrue);
    expect(hasher.verify('demo12345', hash), isFalse);
  });

  test('ista lozinka daje razlicite hesove (so)', () {
    expect(hasher.hash('demo1234'), isNot(hasher.hash('demo1234')));
  });

  test('cena je upisana u hes', () {
    expect(const PasswordHasher().hash('x'), startsWith(r'$2a$10$'));
  });

  test('neispravan hes je "ne odgovara", a ne izuzetak', () {
    expect(hasher.verify('demo1234', 'nije-hes'), isFalse);
  });
}
