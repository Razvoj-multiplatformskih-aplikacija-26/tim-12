// Sastavljanje servera: rute i middleware na jednom mestu.
//
// `buildApp` ne zna za mrezu (port, adresa) — to radi `bin/server.dart`.
// Tako testovi podizu isti app na slucajnom portu, bez dupliranja ruta.
import 'package:relic/relic.dart';

/// Pravi aplikaciju sa svim rutama servera.
RelicApp buildApp() {
  return RelicApp()
    ..use('/', logRequests())
    ..get('/health', _health);
}

/// Provera zivosti: Docker Compose i klijenti po njoj znaju da server radi.
Response _health(Request request) => Response.ok(
  body: Body.fromString('{"status":"ok"}', mimeType: MimeType.json),
);
