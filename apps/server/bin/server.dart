// Ulazna tacka servera: podesavanja, baza, migracije, pocetni podaci, HTTP.
//
// Slusa na svim adresama (0.0.0.0), jer u Docker kontejneru loopback nije
// dostupan spolja. Pri pokretanju van Docker-a cita i `.env` iz korena
// repozitorijuma; promenljive iz okruzenja imaju prednost nad fajlom.
import 'dart:async';
import 'dart:io';

import 'package:radioroom_server/radioroom_server.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  final Config config;
  try {
    config = Config.fromEnvironment({
      ...readDotEnv(File('../../.env')),
      ...readDotEnv(File('.env')),
      ...Platform.environment,
    });
  } on ConfigException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
    return;
  }

  final db = await openDatabase(config);
  final applied = await migrate(db, directory: Directory('migrations'));
  stdout.writeln(
    applied.isEmpty
        ? 'Sema je azurna'
        : 'Primenjene migracije: ${applied.join(', ')}',
  );
  if (await seedIfEmpty(
    db,
    hasher: const PasswordHasher(),
    now: DateTime.now(),
  )) {
    stdout.writeln(
      'Upisani pocetni podaci (demo nalozi: lozinka $demoPassword)',
    );
  }

  final app = buildApp();
  final server = await app.serve(
    address: InternetAddress.anyIPv4,
    port: config.port,
  );
  stdout.writeln('RadioRoom server slusa na portu ${server.port}');

  // U kontejneru je server proces broj 1, koji bez rukovaoca ignorise
  // SIGTERM — `docker compose down` bi ga posle 10 s ubio na silu.
  // Ctrl+C (SIGINT) i SIGTERM zatvaraju server i bazu uredno.
  late final List<StreamSubscription<ProcessSignal>> subscriptions;
  Future<void> shutdown(ProcessSignal signal) async {
    for (final s in subscriptions) {
      await s.cancel();
    }
    stdout.writeln('Gasenje servera ($signal)');
    await app.close();
    await db.close();
  }

  subscriptions = [
    ProcessSignal.sigint.watch().listen(shutdown),
    ProcessSignal.sigterm.watch().listen(shutdown),
  ];
}
