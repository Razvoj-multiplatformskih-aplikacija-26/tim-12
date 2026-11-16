// Pravi server za testove: isti `buildApp` kao u produkciji, nad
// privremenom semom sa migracijama i pocetnim podacima, na slucajnom portu.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:radioroom_server/radioroom_server.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

Map<String, String> get _env => {
  ...readDotEnv(File('../../.env.example')),
  ...readDotEnv(File('../../.env')),
  ...Platform.environment,
};

final class TestServer {
  TestServer._(this.base);

  final Uri base;

  Future<http.Response> get(String path, {String? token}) =>
      http.get(base.resolve(path), headers: _headers(token));

  Future<http.Response> post(String path, {Object? body, String? token}) =>
      http.post(
        base.resolve(path),
        headers: _headers(token),
        body: body == null ? null : jsonEncode(body),
      );

  /// Prijava demo nalogom; vraca token.
  Future<String> login(String username, {String app = 'mobile'}) async {
    final response = await post(
      '/auth/login',
      body: {'username': username, 'password': demoPassword, 'app': app},
    );
    expect(response.statusCode, 200, reason: response.body);
    return (jsonDecode(response.body) as Map)['token'] as String;
  }

  Map<String, String> _headers(String? token) => {
    'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  };
}

/// Podize server nad novom semom, ili vraca `null` (test se preskace) kad
/// baza nije dostupna. [clock] menja "sad" servera (istek prijave).
Future<TestServer?> startTestServer({
  DateTime Function()? clock,
  Duration sessionTtl = const Duration(minutes: 60),
}) async {
  final config = Config.fromEnvironment(_env);
  final endpoint = Endpoint(
    host: config.dbHost,
    port: config.dbPort,
    database: config.dbName,
    username: config.dbUser,
    password: config.dbPassword,
  );

  final Connection admin;
  try {
    admin = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
  } on Object catch (error) {
    if (_env['REQUIRE_DB'] == '1') rethrow;
    markTestSkipped('Baza nije dostupna ($error) — `docker compose up db`');
    return null;
  }

  final schema = 'test_${Random().nextInt(1 << 32).toRadixString(16)}';
  await admin.execute('CREATE SCHEMA $schema');
  // Svaka konekcija pool-a radi u privremenoj semi.
  final pool = Pool<void>.withEndpoints(
    [endpoint],
    settings: PoolSettings(
      maxConnectionCount: 4,
      sslMode: SslMode.disable,
      onOpen: (c) => c.execute('SET search_path TO $schema'),
    ),
  );
  const hasher = PasswordHasher(cost: 4);
  final now = clock ?? DateTime.now;
  await migrate(pool, directory: Directory('migrations'));
  await seedIfEmpty(pool, hasher: hasher, now: now());

  final app = buildApp(
    db: pool,
    sessionTtl: sessionTtl,
    corsOrigins: config.corsOrigins,
    hasher: hasher,
    clock: now,
  );
  final server = await app.serve(port: 0);
  addTearDown(() async {
    await app.close();
    await pool.close();
    await admin.execute('DROP SCHEMA $schema CASCADE');
    await admin.close();
  });
  return TestServer._(Uri.parse('http://localhost:${server.port}'));
}
