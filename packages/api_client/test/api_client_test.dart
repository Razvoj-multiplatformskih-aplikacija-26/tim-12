// Testovi tankog HTTP klijenta: zaglavlja, `{code, data}` greske i prijava.
//
// Bez zivog servera: `MockClient` iz `package:http/testing` vraca unapred
// spremljene odgovore. Integraciona provera protiv servera je rucna
// (curl komande u terminal manifestu celine).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radioroom_api_client/radioroom_api_client.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:test/test.dart';

void main() {
  group('ApiClient zaglavlja', () {
    test('salje Bearer token kad ga provider vrati', () async {
      String? seen;
      final api = ApiClient(
        baseUrl: 'http://test',
        tokenProvider: () async => 'tok123',
        client: MockClient((request) async {
          seen = request.headers['Authorization'];
          return http.Response('{}', 200);
        }),
      );
      await api.getJson('/rooms');
      expect(seen, 'Bearer tok123');
    });

    test('bez tokena nema Authorization zaglavlja', () async {
      String? seen = 'prisutno';
      final api = ApiClient(
        baseUrl: 'http://test',
        tokenProvider: () async => null,
        client: MockClient((request) async {
          seen = request.headers['Authorization'];
          return http.Response('{}', 200);
        }),
      );
      await api.getJson('/rooms');
      expect(seen, isNull);
    });
  });

  group('ApiClient greske', () {
    test('{code, data} sa kodom pravila postaje ServerRejected', () async {
      final api = _api(
        http.Response(
          jsonEncode({
            'code': 'already_voted_in_round',
            'data': {'voterId': 'u1', 'roundId': 'rd-r1'},
          }),
          422,
        ),
      );
      final error = await _rejection(() => api.getJson('/rooms/r1'));
      expect(error.code, ErrorCodes.alreadyVotedInRound);
      expect(error.data['voterId'], 'u1');
    });

    test('404 room_not_found prolazi kao ServerRejected', () async {
      final api = _api(http.Response(jsonEncode({'code': 'room_not_found'}), 404));
      final error = await _rejection(() => api.getJson('/rooms/r9'));
      expect(error.code, ErrorCodes.roomNotFound);
      expect(error.isKnown, isTrue);
    });

    test('nepoznat kod prolazi kao ServerRejected (stara verzija)', () async {
      final api = _api(http.Response(jsonEncode({'code': 'buduce_pravilo'}), 422));
      final error = await _rejection(() => api.getJson('/rooms/r1'));
      expect(error.code, 'buduce_pravilo');
      expect(error.isKnown, isFalse);
    });

    test('ne-JSON telo je genericki Exception, ne ServerRejected', () async {
      final api = _api(http.Response('<html>pad</html>', 500));
      await expectLater(
        api.getJson('/rooms'),
        throwsA(isA<Exception>().having((e) => e, 'tip', isNot(isA<ServerRejected>()))),
      );
    });

    test('istek cekanja je genericki Exception, ne ServerRejected', () async {
      final api = ApiClient(
        baseUrl: 'http://test',
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.getJson('/rooms'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('mrezni kvar propagira kao genericki Exception', () async {
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => throw http.ClientException('nema mreze')),
      );
      await expectLater(
        api.getJson('/rooms'),
        throwsA(isA<Exception>().having((e) => e, 'tip', isNot(isA<ServerRejected>()))),
      );
    });
  });

  group('ApiClient prijava', () {
    test('login salje kredencijale i vraca token, rok i korisnika', () async {
      Map<String, Object?>? seen;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seen = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'token': 'tok123',
              'expiresAt': '2026-11-22T00:00:00.000Z',
              'user': {'id': 'u1', 'displayName': 'Pera', 'role': 'listener'},
            }),
            200,
          );
        }),
      );
      final response = await api.login(
        username: 'pera',
        password: 'tajna',
        app: AppTarget.mobile,
      );
      expect(seen, {'username': 'pera', 'password': 'tajna', 'app': 'mobile'});
      expect(response.token, 'tok123');
      expect(response.user.displayName, 'Pera');
    });

    test('pogresni kredencijali postaju ServerRejected', () async {
      final api = _api(
        http.Response(jsonEncode({'code': 'invalid_credentials'}), 401),
      );
      final error = await _rejection(
        () => api.login(username: 'pera', password: 'lose'),
      );
      expect(error.code, ErrorCodes.invalidCredentials);
    });

    test('me vraca korisnika iz vazece prijave', () async {
      final api = ApiClient(
        baseUrl: 'http://test',
        tokenProvider: () async => 'tok123',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer tok123');
          return http.Response(
            jsonEncode({'id': 'u1', 'displayName': 'Pera', 'role': 'host'}),
            200,
          );
        }),
      );
      final user = await api.me();
      expect(user.id.value, 'u1');
    });

    test('istekla prijava postaje ServerRejected sa session_expired', () async {
      final api = _api(
        http.Response(jsonEncode({'code': 'session_expired'}), 401),
      );
      final error = await _rejection(api.me);
      expect(error.code, ErrorCodes.sessionExpired);
    });
  });
}

/// Klijent sa jednim spremljenim odgovorom za svaki poziv.
ApiClient _api(http.Response response) => ApiClient(
  baseUrl: 'http://test',
  client: MockClient((_) async => response),
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
