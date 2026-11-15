// Sastavljanje servera: rute i middleware na jednom mestu.
//
// `buildApp` ne zna za mrezu (port, adresa) — to radi `bin/server.dart`.
// Tako testovi podizu isti app na slucajnom portu, bez dupliranja ruta.
import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart';

import 'auth/auth.dart';
import 'auth/passwords.dart';
import 'auth/sessions.dart';
import 'http/json.dart';

/// Pravi aplikaciju sa svim rutama servera.
RelicApp buildApp({
  required Session db,
  required Duration sessionTtl,
  PasswordHasher hasher = const PasswordHasher(),
  DateTime Function() clock = DateTime.now,
}) {
  final sessions = SessionStore(db, ttl: sessionTtl, clock: clock);
  final app = RelicApp()
    ..use('/', logRequests())
    ..use('/', requireSession(sessions))
    ..get('/health', _health);
  AuthRoutes(db: db, sessions: sessions, hasher: hasher).mount(app);
  return app;
}

/// Provera zivosti: Docker Compose i klijenti po njoj znaju da server radi.
Response _health(Request request) => jsonResponse({'status': 'ok'});
