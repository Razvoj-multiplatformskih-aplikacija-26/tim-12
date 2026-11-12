// Ulazna tacka servera: cita port iz okruzenja i podize aplikaciju.
//
// Slusa na svim adresama (0.0.0.0), jer u Docker kontejneru loopback nije
// dostupan spolja. Port dolazi iz `PORT` (podrazumevano 8080).
import 'dart:async';
import 'dart:io';

import 'package:radioroom_server/radioroom_server.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final app = buildApp();
  final server = await app.serve(address: InternetAddress.anyIPv4, port: port);
  stdout.writeln('RadioRoom server slusa na portu ${server.port}');

  // U kontejneru je server proces broj 1, koji bez rukovaoca ignorise
  // SIGTERM — `docker compose down` bi ga posle 10 s ubio na silu.
  // Ctrl+C (SIGINT) i SIGTERM zatvaraju server uredno.
  late final List<StreamSubscription<ProcessSignal>> subscriptions;
  Future<void> shutdown(ProcessSignal signal) async {
    for (final s in subscriptions) {
      await s.cancel();
    }
    stdout.writeln('Gasenje servera ($signal)');
    await app.close();
  }

  subscriptions = [
    ProcessSignal.sigint.watch().listen(shutdown),
    ProcessSignal.sigterm.watch().listen(shutdown),
  ];
}
