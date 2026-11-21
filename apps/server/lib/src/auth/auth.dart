// Prijava, odjava i provera prijave pri svakom pozivu.
//
// Server zna ko poziva SAMO iz prijave koju je sam izdao: middleware cita
// `Authorization: Bearer <token>`, trazi prijavu u bazi i tek tada pusta
// zahtev dalje. Identitet iz tela zahteva (npr. `userId`) se nikad ne cita.
//
// Svaka ruta trazi prijavu, osim onih u [publicPaths] — nova ruta je
// zasticena sama od sebe, ne moze se zaboraviti.
import 'package:postgres/postgres.dart' show Session;
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mapping/radioroom_mapping.dart';
import 'package:relic/relic.dart';

import '../http/json.dart';
import '../http/rule_errors.dart';
import 'passwords.dart';
import 'sessions.dart';
import 'users.dart';

/// Rute dostupne bez prijave (odluka para: u KT2 bez prijave nema sadrzaja;
/// javni sadrzaj stize sa javnim vebom u KT4).
const publicPaths = {'/health', '/auth/login'};

final _currentUser = ContextProperty<User>('currentUser');

extension CurrentUser on Request {
  /// Korisnik iz prijave koju je server izdao; postoji na svakoj ruti van
  /// [publicPaths].
  User get currentUser => _currentUser.get(this);
}

/// Middleware: proverava prijavu pri svakom pozivu zasticene rute.
Middleware requireSession(SessionStore sessions) =>
    (next) => (request) async {
      if (publicPaths.contains(request.url.path)) return next(request);

      final token = _bearerToken(request);
      if (token == null) return errorResponse(ErrorCodes.unauthenticated);

      switch (await sessions.lookup(token)) {
        case UnknownSession():
          return errorResponse(ErrorCodes.unauthenticated);
        case ExpiredSession():
          return errorResponse(ErrorCodes.sessionExpired);
        case ActiveSession(:final user):
          // Blokiran tokom prijave: prijava vise ne vazi ni za citanje.
          if (user.blocked) return errorResponse(ErrorCodes.userBlocked);
          _currentUser[request] = user;
          return next(request);
      }
    };

/// Rute prijave: `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`.
final class AuthRoutes {
  AuthRoutes({required this.db, required this.sessions, required this.hasher})
    : _dummyHash = hasher.hash('nepostojeci-korisnik');

  final Session db;
  final SessionStore sessions;
  final PasswordHasher hasher;

  /// Hes za proveru kad korisnik ne postoji: prijava traje isto i za
  /// nepostojece ime, pa se po vremenu odgovora ne vidi koja imena postoje.
  final String _dummyHash;

  void mount(RelicApp app) {
    app
      ..post('/auth/login', login)
      ..post('/auth/logout', logout)
      ..get('/auth/me', me);
  }

  /// Telo: `LoginRequest` (`{username, password, app}`); `app` je `mobile`
  /// (podrazumevano) ili `backoffice`. Server primenjuje isto domensko
  /// pravilo kao klijent (`checkCanUseMobile` / `checkCanUseBackoffice`) i
  /// isti kod greske.
  Future<Response> login(Request request) async {
    final body = await readRequest(request, LoginRequest.fromJson);
    if (body == null) return errorResponse(ErrorCodes.badRequest);

    final found = await findForLogin(db, body.username.trim());
    if (found == null) {
      hasher.verify(body.password, _dummyHash);
      return errorResponse(ErrorCodes.invalidCredentials);
    }
    final (user, hash) = found;
    if (!hasher.verify(body.password, hash)) {
      return errorResponse(ErrorCodes.invalidCredentials);
    }

    final outcome = body.app == AppTarget.backoffice
        ? checkCanUseBackoffice(user: user)
        : checkCanUseMobile(user: user);
    if (outcome.error case final error?) return ruleErrorResponse(error);

    final (token, expiresAt) = await sessions.create(user.id);
    return jsonResponse(
      LoginResponse(
        token: token,
        expiresAt: expiresAt,
        user: user.toDto(),
      ).toJson(),
    );
  }

  /// Odjava brise prijavu iz koje je poziv stigao.
  Future<Response> logout(Request request) async {
    await sessions.delete(_bearerToken(request)!);
    return Response(204);
  }

  /// Ko sam ja — klijent po ovome posle ponovnog pokretanja zna da li
  /// sacuvana prijava jos vazi.
  Response me(Request request) =>
      jsonResponse(request.currentUser.toDto().toJson());
}

String? _bearerToken(Request request) {
  final header = request.headers['authorization']?.firstOrNull;
  const prefix = 'Bearer ';
  if (header == null || !header.startsWith(prefix)) return null;
  final token = header.substring(prefix.length).trim();
  return token.isEmpty ? null : token;
}
