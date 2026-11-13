import 'dart:convert';
import 'dart:io';

import 'package:radioroom_server/radioroom_server.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  late RelicApp app;
  late int port;

  setUp(() async {
    app = buildApp();
    // Port 0: sistem bira slobodan port, pa testovi ne smetaju jedni drugima.
    final server = await app.serve(port: 0);
    port = server.port;
  });

  tearDown(() => app.close());

  test('GET /health vraca 200 i status ok', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final response = await (await client.get(
      'localhost',
      port,
      '/health',
    )).close();
    final body = await response.transform(utf8.decoder).join();

    expect(response.statusCode, 200);
    expect(response.headers.contentType?.mimeType, 'application/json');
    expect(jsonDecode(body), {'status': 'ok'});
  });

  test('nepoznata ruta vraca 404', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final response = await (await client.get(
      'localhost',
      port,
      '/nema',
    )).close();
    await response.drain<void>();

    expect(response.statusCode, 404);
  });
}
