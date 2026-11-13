import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:radioroom_server/radioroom_server.dart';
import 'package:test/test.dart';

import 'support/test_db.dart';

void main() {
  final migrations = Directory('migrations');

  test('primenjuje migracije jednom; drugo pokretanje ne radi nista',
      () async {
    final db = await openTestSchema();
    if (db == null) return;

    expect(await migrate(db, directory: migrations), ['001_schema.sql']);
    expect(await migrate(db, directory: migrations), isEmpty);

    final tables = await db.execute(
      "SELECT table_name FROM information_schema.tables "
      "WHERE table_schema = current_schema() ORDER BY table_name",
    );
    expect(tables.map((r) => r[0]), [
      'proposals',
      'rooms',
      'rounds',
      'schema_migrations',
      'sessions',
      'users',
      'votes',
    ]);
  });

  test('migracija koja padne ne ostavlja polovicnu semu', () async {
    final db = await openTestSchema();
    if (db == null) return;
    final dir = Directory.systemTemp.createTempSync('migrations');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/001_ok.sql').writeAsStringSync('CREATE TABLE a (x int);');
    File('${dir.path}/002_pada.sql')
        .writeAsStringSync('CREATE TABLE b (x int); OVO NIJE SQL;');

    await expectLater(migrate(db, directory: dir), throwsA(anything));

    final tables = await db.execute(
      "SELECT table_name FROM information_schema.tables "
      "WHERE table_schema = current_schema() ORDER BY table_name",
    );
    expect(tables.map((r) => r[0]), ['a', 'schema_migrations']);
    final applied = await db.execute('SELECT name FROM schema_migrations');
    expect(applied.map((r) => r[0]), ['001_ok.sql']);
  });

  group('ogranicenja seme', () {
    /// Migrirana sema sa jednim slusaocem, sobom, rundom i predlogom.
    Future<Connection?> seeded() async {
      final db = await openTestSchema();
      if (db == null) return null;
      await migrate(db, directory: migrations);
      await db.execute('''
        INSERT INTO users (id, username, display_name, password_hash, role)
          VALUES ('u1', 'ana', 'Ana', 'hes', 'listener');
        INSERT INTO rooms (id, name, host_id) VALUES ('r1', 'Soba', 'u1');
        INSERT INTO rounds (id, room_id, starts_at, ends_at)
          VALUES ('k1', 'r1', now(), now() + interval '5 minutes');
        INSERT INTO proposals (id, room_id, title, artist, proposed_by, status)
          VALUES ('p1', 'r1', 'Pesma', 'Izvodjac', 'u1', 'in_voting');
      ''', queryMode: QueryMode.simple);
      return db;
    }

    const vote = "INSERT INTO votes (round_id, proposal_id, voter_id) "
        "VALUES ('k1', 'p1', 'u1')";

    test('baza odbija drugi glas istog slusaoca u istoj rundi', () async {
      final db = await seeded();
      if (db == null) return;
      await db.execute(vote);

      await expectLater(
        db.execute(vote),
        throwsA(
          isA<ServerException>()
              .having((e) => e.code, 'code', '23505')
              .having((e) => e.constraintName, 'constraint',
                  'votes_one_per_round'),
        ),
      );
    });

    test('baza odbija nepoznato stanje predloga', () async {
      final db = await seeded();
      if (db == null) return;

      await expectLater(
        db.execute("UPDATE proposals SET status = 'nepoznato'"),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', '23514')),
      );
    });

    test('pusten predlog mora imati vreme pustanja', () async {
      final db = await seeded();
      if (db == null) return;

      await expectLater(
        db.execute("UPDATE proposals SET status = 'played'"),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', '23514')),
      );
      await db.execute(
        "UPDATE proposals SET status = 'played', played_at = now()",
      );
    });
  });
}
