// HTTP implementacija porta prijave — AuthBloc se ne menja.
//
// Token putuje samo u `Authorization` zaglavlju (cita ga server iz svoje
// prijave): portov argument `me(token)` je dokumentacija toka, identitet se
// iz njega ne salje niti cita. Klijent nikad ne salje `userId` kao identitet.
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'api_client.dart';

final class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required AppTarget app,
  }) async {
    final response = await _api.login(
      username: username,
      password: password,
      app: app,
    );
    return AuthSession(
      user: response.user.toDomain(),
      token: response.token,
      expiresAt: response.expiresAt,
    );
  }

  @override
  Future<User> me(String token) => _api.me();

  @override
  Future<void> logout() => _api.logout();
}
