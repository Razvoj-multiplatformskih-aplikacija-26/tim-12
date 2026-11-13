// Primena migracija: SQL fajlovi iz `migrations/`, redom po imenu.
//
// Svaki fajl se primenjuje jednom, u sopstvenoj transakciji, i belezi se u
// tabeli `schema_migrations`. Fajl koji padne ne ostavlja polovicnu semu —
// transakcija se ponistava i server ne krece. Primenjen fajl se ne menja:
// izmena seme je uvek nov fajl sa sledecim brojem.
import 'dart:io';

import 'package:postgres/postgres.dart';

/// Primenjuje neprimenjene migracije iz [directory] i vraca njihova imena.
Future<List<String>> migrate(
  SessionExecutor db, {
  required Directory directory,
}) async {
  final applied = await db.run((session) async {
    await session.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name       text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    ''');
    final rows = await session.execute('SELECT name FROM schema_migrations');
    return {for (final row in rows) row[0]! as String};
  });

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final newlyApplied = <String>[];
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (applied.contains(name)) continue;
    final sql = await file.readAsString();
    await db.runTx((tx) async {
      // Prost rezim dozvoljava vise naredbi u jednom pozivu (ceo fajl).
      await tx.execute(sql, queryMode: QueryMode.simple);
      await tx.execute(
        Sql.named('INSERT INTO schema_migrations (name) VALUES (@name)'),
        parameters: {'name': name},
      );
    });
    newlyApplied.add(name);
  }
  return newlyApplied;
}
