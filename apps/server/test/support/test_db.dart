// Pomoc za testove nad pravom bazom (Postgres iz docker compose-a).
//
// Svaki test dobija sopstvenu privremenu semu: migracije i podaci testa ne
// diraju pravu semu baze, a sema se brise posle testa. Kad baza nije
// podignuta, testovi se preskacu — osim ako je postavljeno REQUIRE_DB=1
// (CI), kada nedostupna baza obara test umesto da ga tiho preskoci.
import 'dart:io';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:radioroom_server/radioroom_server.dart';
import 'package:test/test.dart';

Map<String, String> get _env => {
  ...readDotEnv(File('../../.env.example')),
  ...readDotEnv(File('../../.env')),
  ...Platform.environment,
};

/// Otvara konekciju u novoj praznoj semi, ili vraca `null` (i preskace
/// test) kad baza nije dostupna.
Future<Connection?> openTestSchema() async {
  final config = Config.fromEnvironment(_env);
  final Connection connection;
  try {
    connection = await Connection.open(
      Endpoint(
        host: config.dbHost,
        port: config.dbPort,
        database: config.dbName,
        username: config.dbUser,
        password: config.dbPassword,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
  } on Object catch (error) {
    if (_env['REQUIRE_DB'] == '1') rethrow;
    markTestSkipped('Baza nije dostupna ($error) — `docker compose up db`');
    return null;
  }

  final schema = 'test_${Random().nextInt(1 << 32).toRadixString(16)}';
  await connection.execute('CREATE SCHEMA $schema');
  await connection.execute('SET search_path TO $schema');
  addTearDown(() async {
    await connection.execute('DROP SCHEMA $schema CASCADE');
    await connection.close();
  });
  return connection;
}
