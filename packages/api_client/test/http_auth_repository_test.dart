// HTTP implementacija porta prijave i `onAuthFailure` povratni poziv.
//
// Bez zivog servera: `MockClient` iz `package:http/testing` vraca unapred
// spremljene odgovore (isti obrazac kao `api_client_test.dart`).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radioroom_api_client/radioroom_api_client.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:test/test.dart';

/// Klijent sa jednim spremljenim odgovorom za svaki poziv.
ApiClient _api(
  http.Response response, {
  AuthFailureCallback? onAuthFailure,
  List<String>? seenPaths,
}) => ApiClient(
  baseUrl: 'http://test',
  tokenProvider: () async => 'tok123',
  onAuthFailure: onAuthFailure,
  client: MockClient((request) async {
    seenPaths?.add(request.url.path);
    return response;
  }),
);

/// Izvadi `ApiError` iz bacenog `ServerRejected`.
Future<ApiError> _rejection(Future<void> Function() call) async {
  try {
    await call();
  } on ServerRejected catch (rejected) {
    return rejected.error;
  }
  return fail('ocekivano ServerRejected, proslo bez greske');
}

Map<String, Object?> _loginBody() => {
  'token': 'tok123',
  'expiresAt': '2026-11-22T00:00:00.000Z',
  'user': {'id': 'u1', 'displayName': 'Ana', 'role': 'listener'},
};

void main() {
  group('HttpAuthRepository', () {
    test('login vraca sesiju sa korisnikom, tokenom i rokom', () async {
      final repository = HttpAuthRepository(
        _api(http.Response(jsonEncode(_loginBody()), 200)),
      );
      final session = await repository.login(
        username: 'ana',
        password: 'demo1234',
        app: AppTarget.mobile,
      );
      expect(session.token, 'tok123');
      expect(session.user.displayName, 'Ana');
      expect(session.expiresAt, DateTime.utc(2026, 11, 22));
    });

    test('pogresni kredencijali postaju ServerRejected', () async {
      final repository = HttpAuthRepository(
        _api(http.Response(jsonEncode({'code': 'invalid_credentials'}), 401)),
      );
      final error = await _rejection(
        () => repository.login(
          username: 'ana',
          password: 'lose',
          app: AppTarget.mobile,
        ),
      );
      expect(error.code, ErrorCodes.invalidCredentials);
    });

    test('zabranjena aplikacija nosi backoffice_not_allowed', () async {
      final repository = HttpAuthRepository(
        _api(
          http.Response(
            jsonEncode({
              'code': 'backoffice_not_allowed',
              'data': {'role': 'listener'},
            }),
            403,
          ),
        ),
      );
      final error = await _rejection(
        () => repository.login(
          username: 'ana',
          password: 'demo1234',
          app: AppTarget.backoffice,
        ),
      );
      expect(error.code, ErrorCodes.backofficeNotAllowed);
      expect(error.data['role'], 'listener');
    });

    test('me vraca korisnika iz vazece prijave', () async {
      final repository = HttpAuthRepository(
        _api(
          http.Response(
            jsonEncode({'id': 'u1', 'displayName': 'Ana', 'role': 'host'}),
            200,
          ),
        ),
      );
      final user = await repository.me('tok123');
      expect(user.id.value, 'u1');
      expect(user.displayName, 'Ana');
    });

    test('logout salje POST na /auth/logout i trpi prazan odgovor', () async {
      final seenPaths = <String>[];
      final repository = HttpAuthRepository(
        _api(http.Response('', 204), seenPaths: seenPaths),
      );
      await repository.logout();
      expect(seenPaths, ['/auth/logout']);
    });
  });

  group('onAuthFailure', () {
    test('401 session_expired sa data rute javlja i baca', () async {
      ApiError? seen;
      final api = _api(
        http.Response(jsonEncode({'code': 'session_expired'}), 401),
        onAuthFailure: (error) => seen = error,
      );
      final error = await _rejection(() => api.getJson('/rooms/r1'));
      expect(error.code, ErrorCodes.sessionExpired);
      expect(seen?.code, ErrorCodes.sessionExpired);
    });

    test('401 unauthenticated sa /auth/me javlja', () async {
      ApiError? seen;
      final api = _api(
        http.Response(jsonEncode({'code': 'unauthenticated'}), 401),
        onAuthFailure: (error) => seen = error,
      );
      await _rejection(api.me);
      expect(seen?.code, ErrorCodes.unauthenticated);
    });

    test('401 sa samog /auth/login ne javlja (pogresna lozinka)', () async {
      var called = false;
      final api = _api(
        http.Response(jsonEncode({'code': 'invalid_credentials'}), 401),
        onAuthFailure: (_) => called = true,
      );
      final error = await _rejection(
        () => api.login(username: 'ana', password: 'lose'),
      );
      expect(error.code, ErrorCodes.invalidCredentials);
      expect(called, isFalse);
    });

    test('bez povratnog poziva odbacivanje i dalje baca', () async {
      final api = _api(
        http.Response(jsonEncode({'code': 'session_expired'}), 401),
      );
      final error = await _rejection(() => api.getJson('/rooms'));
      expect(error.code, ErrorCodes.sessionExpired);
    });
  });
}
