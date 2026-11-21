// Lazna prijava za testove: korisnici i sesije u memoriji, bez mreze.
//
// Ponasa se kao server: pogresna lozinka je `invalid_credentials`,
// nepoznat token je `unauthenticated`, a prijava u backoffice nalogom koji
// nije moderator je `backoffice_not_allowed` (ista domenska pravila, isti
// kodovi kao `apps/server` README).
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

final class FakeAuthRepository implements AuthRepository {
  /// Lozinka svih laznih naloga (kao `demo1234` na serveru).
  static const password = 'demo1234';

  final _users = const {
    'ana': User(id: UserId('u1'), displayName: 'Ana', role: Role.listener),
    'moderator': User(
      id: UserId('m1'),
      displayName: 'Moderator',
      role: Role.moderator,
    ),
  };

  final _sessions = <String, User>{};

  int logoutCalls = 0;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required AppTarget app,
  }) async {
    final user = _users[username.trim()];
    if (user == null || password != FakeAuthRepository.password) {
      throw const ServerRejected(
        ApiError(code: ErrorCodes.invalidCredentials),
      );
    }
    if (app == AppTarget.backoffice && user.role != Role.moderator) {
      throw ServerRejected(
        ApiError(
          code: ErrorCodes.backofficeNotAllowed,
          data: {'role': user.role.name},
        ),
      );
    }
    final token = 'tok-$username';
    _sessions[token] = user;
    return AuthSession(
      user: user,
      token: token,
      expiresAt: DateTime.utc(2027),
    );
  }

  @override
  Future<User> me(String token) async {
    final user = _sessions[token];
    if (user == null) {
      throw const ServerRejected(ApiError(code: ErrorCodes.unauthenticated));
    }
    return user;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

/// Token u memoriji umesto bezbednog skladista (bez platformskog kanala).
final class FakeTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteToken() async {
    token = null;
  }
}

/// Prijavljen AuthBloc za testove rutera: obavi prijavu do kraja pre
/// gradnje rutera, pa cuvar odmah pusta na zasticene adrese.
Future<AuthBloc> authenticatedBloc({
  FakeAuthRepository? repository,
  FakeTokenStore? store,
  String username = 'ana',
  AppTarget app = AppTarget.mobile,
}) async {
  final auth = AuthBloc(
    repository: repository ?? FakeAuthRepository(),
    tokenStore: store ?? FakeTokenStore(),
  );
  auth.add(
    LoginRequested(
      username: username,
      password: FakeAuthRepository.password,
      app: app,
    ),
  );
  await auth.stream.firstWhere((state) => state is Authenticated);
  return auth;
}
