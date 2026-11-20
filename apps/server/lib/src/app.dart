// Sastavljanje servera: rute i middleware na jednom mestu.
//
// `buildApp` ne zna za mrezu (port, adresa) — to radi `bin/server.dart`.
// Tako testovi podizu isti app na slucajnom portu, bez dupliranja ruta.
import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart';

import 'auth/auth.dart';
import 'auth/passwords.dart';
import 'auth/sessions.dart';
import 'catalog/catalog_routes.dart';
import 'catalog/song_catalog.dart';
import 'http/cors.dart';
import 'http/json.dart';
import 'rooms/room_routes.dart';

/// Pravi aplikaciju sa svim rutama servera.
///
/// Dva sloja: spoljni prima SVAKI zahtev (log, CORS), unutrasnji rutira.
/// Relic-ov `use` obmotava samo rute koje se poklope, a na putanju bez te
/// metode (npr. `OPTIONS /auth/login`) sam odgovara 405 — preflight tako ne
/// bi ni stigao do CORS-a. Odbaceno: ruta `options('/**')` — tacna ruta
/// ima prednost (opet 405), a nepostojeca putanja daje 405 umesto 404.
RelicApp buildApp({
  required Pool<void> db,
  required Duration sessionTtl,
  Duration roundLength = const Duration(minutes: 10),
  required Set<String> corsOrigins,
  required SongCatalog catalog,
  Duration catalogTimeout = const Duration(seconds: 5),
  PasswordHasher hasher = const PasswordHasher(),
  DateTime Function() clock = DateTime.now,
}) {
  final sessions = SessionStore(db, ttl: sessionTtl, clock: clock);
  final routes = RelicApp()
    ..use('/', requireSession(sessions))
    ..get('/health', _health);
  AuthRoutes(db: db, sessions: sessions, hasher: hasher).mount(routes);
  CatalogRoutes(catalog: catalog, timeout: catalogTimeout).mount(routes);
  RoomRoutes(db: db, roundLength: roundLength, clock: clock).mount(routes);

  return RelicApp()
    ..use('/', logRequests())
    ..use('/', cors(corsOrigins))
    ..any('/**', routes.asHandler);
}

/// Provera zivosti: Docker Compose i klijenti po njoj znaju da server radi.
Response _health(Request request) => jsonResponse({'status': 'ok'});
