// Prijava, odjava, istek i provera prijave pri svakom pozivu (#25).
import 'dart:convert';

import 'package:test/test.dart';

import 'support/test_server.dart';

Map<String, Object?> _json(String body) =>
    jsonDecode(body) as Map<String, Object?>;

void main() {
  group('POST /auth/login', () {
    test('ispravna prijava vraca token, istek i korisnika', () async {
      final server = await startTestServer();
      if (server == null) return;

      final response = await server.post(
        '/auth/login',
        body: {'username': 'ana', 'password': 'demo1234'},
      );

      expect(response.statusCode, 200);
      final body = _json(response.body);
      expect(body['token'], isA<String>());
      expect((body['token']! as String).length, greaterThanOrEqualTo(40));
      expect(DateTime.parse(body['expiresAt']! as String).isUtc, isTrue);
      expect(body['user'], {
        'id': 'u1',
        'displayName': 'Ana',
        'role': 'listener',
      });
    });

    test('pogresna lozinka i nepostojece ime daju istu gresku', () async {
      final server = await startTestServer();
      if (server == null) return;

      for (final (username, password) in [
        ('ana', 'pogresna'),
        ('niko', 'demo1234'),
      ]) {
        final response = await server.post(
          '/auth/login',
          body: {'username': username, 'password': password},
        );
        expect(response.statusCode, 401);
        expect(_json(response.body), {
          'code': 'invalid_credentials',
          'data': {},
        });
      }
    });

    test('lose telo zahteva je 400', () async {
      final server = await startTestServer();
      if (server == null) return;

      for (final body in [
        null,
        {'username': 'ana'},
        {'username': 'ana', 'password': 'demo1234', 'app': 'tv'},
      ]) {
        final response = await server.post('/auth/login', body: body);
        expect(response.statusCode, 400, reason: '$body');
        expect(_json(response.body)['code'], 'bad_request');
      }
    });

    test('blokiran nalog se ne prijavljuje', () async {
      final server = await startTestServer();
      if (server == null) return;

      final response = await server.post(
        '/auth/login',
        body: {'username': 'spamer', 'password': 'demo1234'},
      );

      expect(response.statusCode, 403);
      expect(_json(response.body)['code'], 'user_blocked');
    });

    test('backoffice odbija slusaoca i hosta i kaze ulogu', () async {
      final server = await startTestServer();
      if (server == null) return;

      for (final (username, role) in [('ana', 'listener'), ('luka', 'host')]) {
        final response = await server.post(
          '/auth/login',
          body: {
            'username': username,
            'password': 'demo1234',
            'app': 'backoffice',
          },
        );
        expect(response.statusCode, 403);
        expect(_json(response.body), {
          'code': 'backoffice_not_allowed',
          'data': {'role': role},
        });
      }
    });

    test('moderator ulazi u backoffice', () async {
      final server = await startTestServer();
      if (server == null) return;

      await server.login('moderator', app: 'backoffice');
    });
  });

  group('provera prijave pri svakom pozivu', () {
    test('GET /auth/me vraca korisnika iz prijave', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('luka');

      final response = await server.get('/auth/me', token: token);

      expect(response.statusCode, 200);
      expect(_json(response.body), {
        'id': 'h1',
        'displayName': 'DJ Luka',
        'role': 'host',
      });
    });

    test(
      'bez tokena ili sa izmisljenim tokenom: 401 unauthenticated',
      () async {
        final server = await startTestServer();
        if (server == null) return;

        for (final token in [null, 'izmisljen-token']) {
          final response = await server.get('/auth/me', token: token);
          expect(response.statusCode, 401);
          expect(_json(response.body)['code'], 'unauthenticated');
        }
      },
    );

    test('odjava brise prijavu: isti token posle ne vazi', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final logout = await server.post('/auth/logout', token: token);
      expect(logout.statusCode, 204);

      final after = await server.get('/auth/me', token: token);
      expect(after.statusCode, 401);
      expect(_json(after.body)['code'], 'unauthenticated');
    });

    test(
      'prijava istice posle vremena iz podesavanja: session_expired',
      () async {
        var now = DateTime.now();
        final server = await startTestServer(
          clock: () => now,
          sessionTtl: const Duration(minutes: 30),
        );
        if (server == null) return;
        final token = await server.login('ana');

        now = now.add(const Duration(minutes: 29));
        expect((await server.get('/auth/me', token: token)).statusCode, 200);

        now = now.add(const Duration(minutes: 1));
        final expired = await server.get('/auth/me', token: token);
        expect(expired.statusCode, 401);
        expect(_json(expired.body)['code'], 'session_expired');

        // Istekla prijava je obrisana: sledeci poziv je obican nepoznat token.
        final again = await server.get('/auth/me', token: token);
        expect(_json(again.body)['code'], 'unauthenticated');
      },
    );

    test('dve prijave istog korisnika su nezavisne (telefon + veb)', () async {
      final server = await startTestServer();
      if (server == null) return;
      final phone = await server.login('ana');
      final web = await server.login('ana');

      await server.post('/auth/logout', token: phone);

      expect((await server.get('/auth/me', token: phone)).statusCode, 401);
      expect((await server.get('/auth/me', token: web)).statusCode, 200);
    });
  });
}
