import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:radioroom_server/radioroom_server.dart';
import 'package:test/test.dart';

import 'support/test_db.dart';

void main() {
  const hasher = PasswordHasher(cost: 4);
  final now = DateTime.utc(2026, 11, 20, 21);

  /// Migrirana sema sa pocetnim podacima.
  Future<Connection?> seeded() async {
    final db = await openTestSchema();
    if (db == null) return null;
    await migrate(db, directory: Directory('migrations'));
    expect(await seedIfEmpty(db, hasher: hasher, now: now), isTrue);
    return db;
  }

  Future<List<List<Object?>>> rows(Connection db, String sql) async => [
    for (final row in await db.execute(sql)) row.toList(),
  ];

  test('bar 10 predloga i bar jedan u svakom stanju', () async {
    final db = await seeded();
    if (db == null) return;

    expect(
      (await rows(db, 'SELECT count(*) FROM proposals')).single.single,
      greaterThanOrEqualTo(10),
    );
    expect(
      (await rows(
        db,
        'SELECT DISTINCT status FROM proposals ORDER BY 1',
      )).map((r) => r.single),
      ['in_voting', 'played', 'proposed', 'rejected', 'removed', 'winner'],
    );
  });

  test('nalog za svaku ulogu i bar dva naloga mobilne aplikacije', () async {
    final db = await seeded();
    if (db == null) return;

    final byRole = {
      for (final r in await rows(
        db,
        'SELECT role, count(*) FROM users GROUP BY role',
      ))
        r[0]: r[1],
    };
    expect(byRole.keys, unorderedEquals(['listener', 'host', 'moderator']));
    expect(
      (byRole['listener']! as int) + (byRole['host']! as int),
      greaterThanOrEqualTo(2),
    );
  });

  test('lozinke su hesovi koji prolaze demo lozinku', () async {
    final db = await seeded();
    if (db == null) return;

    final hashes = (await rows(
      db,
      'SELECT password_hash FROM users',
    )).map((r) => r.single! as String).toList();
    expect(hashes, everyElement(startsWith(r'$2a$')));
    expect(hashes.toSet(), hasLength(hashes.length), reason: 'so po nalogu');
    expect(hashes.every((h) => hasher.verify(demoPassword, h)), isTrue);
  });

  test(
    'vremena su relativna: runda r1 je otvorena, p8 pustena pre 20 min',
    () async {
      final db = await seeded();
      if (db == null) return;

      final round = (await rows(
        db,
        "SELECT starts_at, ends_at FROM rounds WHERE id = 'rd2'",
      )).single;
      expect((round[0]! as DateTime).isBefore(now), isTrue);
      expect((round[1]! as DateTime).isAfter(now), isTrue);

      final playedAt =
          (await rows(
                db,
                "SELECT played_at FROM proposals WHERE id = 'p8'",
              )).single.single!
              as DateTime;
      expect(now.difference(playedAt), const Duration(minutes: 20));
    },
  );

  test('ne upisuje ponovo u bazu koja vec ima korisnike', () async {
    final db = await seeded();
    if (db == null) return;

    expect(await seedIfEmpty(db, hasher: hasher, now: now), isFalse);
    expect((await rows(db, 'SELECT count(*) FROM users')).single.single, 9);
  });
}
