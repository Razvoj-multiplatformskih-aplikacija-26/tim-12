import 'dart:io';

import 'package:radioroom_server/radioroom_server.dart';
import 'package:test/test.dart';

void main() {
  const complete = {
    'PORT': '9000',
    'DB_HOST': 'db',
    'DB_PORT': '5432',
    'DB_NAME': 'radioroom',
    'DB_USER': 'radioroom',
    'DB_PASSWORD': 'tajna',
  };

  test('cita sva podesavanja iz okruzenja', () {
    final config = Config.fromEnvironment(complete);

    expect(config.port, 9000);
    expect(config.dbHost, 'db');
    expect(config.dbPort, 5432);
    expect(config.dbPassword, 'tajna');
  });

  test('PORT nije obavezan (podrazumevano 8080)', () {
    final config = Config.fromEnvironment({...complete}..remove('PORT'));

    expect(config.port, 8080);
  });

  test('prijavljuje sve promenljive koje nedostaju odjednom', () {
    expect(
      () => Config.fromEnvironment({'DB_HOST': 'db', 'DB_PORT': 'x'}),
      throwsA(
        isA<ConfigException>().having((e) => e.missing, 'missing', [
          'DB_PORT (nije broj)',
          'DB_NAME',
          'DB_USER',
          'DB_PASSWORD',
        ]),
      ),
    );
  });

  test('.env.example iz repozitorijuma je potpun', () {
    final env = readDotEnv(File('../../.env.example'));

    expect(() => Config.fromEnvironment(env), returnsNormally);
  });

  test('readDotEnv preskace komentare i prazne redove', () {
    final dir = Directory.systemTemp.createTempSync('env');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/.env')
      ..writeAsStringSync('# komentar\n\nA=1\nB = dva=tri\nlos red\n');

    expect(readDotEnv(file), {'A': '1', 'B': 'dva=tri'});
  });

  test('readDotEnv vraca praznu mapu za fajl koji ne postoji', () {
    expect(readDotEnv(File('/nema/.env')), isEmpty);
  });
}
