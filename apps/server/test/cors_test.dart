// CORS: sam middleware (bez baze) i ceo server (sa bazom) — preflight ne
// sme da padne na proveri prijave ni na rutiranju, a greske nose zaglavlja.
import 'package:http/http.dart' as http;
import 'package:radioroom_server/src/http/cors.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import 'support/test_server.dart';

/// Server samo sa CORS middleware-om i jednom rutom koja vraca 200.
Future<Uri> _serveWithCors(Set<String> origins) async {
  final app = RelicApp()
    ..use('/', cors(origins))
    ..any('/**', (request) => Response.ok());
  final server = await app.serve(port: 0);
  addTearDown(app.close);
  return Uri.parse('http://localhost:${server.port}');
}

Future<http.Response> _send(
  String method,
  Uri url, {
  Map<String, String> headers = const {},
}) async {
  final request = http.Request(method, url)..headers.addAll(headers);
  return http.Response.fromStream(await request.send());
}

const _bo = 'http://localhost:5000';

void main() {
  group('middleware', () {
    test(
      'preflight dobija 204 sa dozvoljenim metodama i zaglavljima',
      () async {
        final base = await _serveWithCors({anyOrigin});

        final response = await _send(
          'OPTIONS',
          base.resolve('/auth/login'),
          headers: {
            'origin': _bo,
            'access-control-request-method': 'POST',
            'access-control-request-headers': 'authorization, content-type',
          },
        );

        expect(response.statusCode, 204);
        expect(response.headers['access-control-allow-origin'], '*');
        expect(
          response.headers['access-control-allow-methods'],
          contains('POST'),
        );
        expect(
          response.headers['access-control-allow-headers'],
          allOf(contains('authorization'), contains('content-type')),
        );
        expect(response.headers['access-control-max-age'], '600');
      },
    );

    test('obican poziv: odgovor rute ostaje, dobija Allow-Origin', () async {
      final base = await _serveWithCors({anyOrigin});

      final response = await _send(
        'GET',
        base.resolve('/x'),
        headers: {'origin': _bo},
      );

      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], '*');
      expect(
        response.headers.containsKey('access-control-allow-methods'),
        isFalse,
      );
    });

    test('izvor sa spiska se vraca tacno, uz Vary: Origin', () async {
      final base = await _serveWithCors({_bo});

      final response = await _send(
        'GET',
        base.resolve('/x'),
        headers: {'origin': _bo},
      );

      expect(response.headers['access-control-allow-origin'], _bo);
      expect(response.headers['vary'], contains('Origin'));
    });

    test('izvor van spiska ne dobija zaglavlja (pregledac odbija)', () async {
      final base = await _serveWithCors({_bo});

      final response = await _send(
        'GET',
        base.resolve('/x'),
        headers: {'origin': 'https://zli.example'},
      );

      expect(
        response.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
    });
  });

  group('ceo server', () {
    test('preflight na /auth/login bez tokena: 204, ne 401 ni 405', () async {
      final server = await startTestServer();
      if (server == null) return;

      final response = await _send(
        'OPTIONS',
        server.base.resolve('/auth/login'),
        headers: {'origin': _bo, 'access-control-request-method': 'POST'},
      );

      expect(response.statusCode, 204);
      expect(response.headers['access-control-allow-origin'], isNotNull);
    });

    test(
      'greska prijave (401) nosi CORS zaglavlje, da je veb klijent procita',
      () async {
        final server = await startTestServer();
        if (server == null) return;

        final response = await _send(
          'GET',
          server.base.resolve('/auth/me'),
          headers: {'origin': _bo},
        );

        expect(response.statusCode, 401);
        expect(response.headers['access-control-allow-origin'], isNotNull);
        expect(response.body, contains('unauthenticated'));
      },
    );
  });
}
