import 'dart:convert';

import 'package:test/test.dart';

import 'support/test_server.dart';

void main() {
  test('GET /health vraca 200 i status ok, bez prijave', () async {
    final server = await startTestServer();
    if (server == null) return;

    final response = await server.get('/health');

    expect(response.statusCode, 200);
    expect(response.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(response.body), {'status': 'ok'});
  });

  test('nepoznata ruta vraca 404 kad je prijava ispravna', () async {
    final server = await startTestServer();
    if (server == null) return;
    final token = await server.login('ana');

    final response = await server.get('/nema', token: token);

    expect(response.statusCode, 404);
  });
}
