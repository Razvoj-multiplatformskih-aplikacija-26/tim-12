// Citanje korisnika iz baze, kao domenskih `User` objekata.
import 'package:postgres/postgres.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Kolone korisnika u redosledu koji ocekuje [userFromRow].
const userColumns = 'u.id, u.display_name, u.role, u.blocked';

/// Red sa [userColumns] u domenski `User`. Uloga je tekstualni kod iz baze
/// (CHECK ogranicenje dozvoljava samo poznate), ime enum vrednosti.
User userFromRow(List<Object?> row, [int offset = 0]) => User(
  id: UserId(row[offset]! as String),
  displayName: row[offset + 1]! as String,
  role: Role.values.byName(row[offset + 2]! as String),
  blocked: row[offset + 3]! as bool,
);

/// Korisnik i hes lozinke po korisnickom imenu (za prijavu), ili `null`.
Future<(User, String)?> findForLogin(Session db, String username) async {
  final rows = await db.execute(
    Sql.named(
      'SELECT $userColumns, u.password_hash FROM users u '
      'WHERE u.username = @username',
    ),
    parameters: {'username': username},
  );
  if (rows.isEmpty) return null;
  final row = rows.single;
  return (userFromRow(row), row[4]! as String);
}
