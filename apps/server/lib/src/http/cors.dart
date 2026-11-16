// CORS: sta pregledac dozvoljava backoffice-u na vebu (druga adresa od
// servera).
//
// Pregledac pre poziva sa `Authorization` zaglavljem salje `OPTIONS`
// (preflight) bez tokena. Zato ovaj middleware stoji ISPRED provere prijave
// i ispred rutiranja: preflight dobija 204, a ne 401 ili 405. Zaglavlja idu i
// na odgovore sa greskom — bez njih pregledac sakrije telo, pa backoffice ne
// bi znao da je razlog `session_expired`, vec bi video samo mreznu gresku.
//
// `*` je bezbedno jer prijava putuje u zaglavlju, ne u kolacicu: tudji sajt
// nema cime da se predstavi kao korisnik. Mobilnu aplikaciju i curl CORS ne
// dotice — to pravilo sprovodi samo pregledac.
import 'package:relic/relic.dart';

/// Svi dozvoljeni izvori (`CORS_ORIGINS=*`).
const anyOrigin = '*';

const _allowMethods = 'GET, POST, PATCH, DELETE';
const _allowHeaders = 'authorization, content-type';

/// Koliko sekundi pregledac pamti odgovor na preflight.
const _maxAgeSeconds = '600';

/// Middleware za [allowedOrigins]: [anyOrigin], ili tacne adrese
/// (`https://backoffice.example`). Izvor van spiska ne dobija zaglavlja, pa
/// pregledac odbija odgovor.
Middleware cors(Set<String> allowedOrigins) =>
    (next) => (request) async {
      final preflight = request.method == Method.options;
      // Server nema svojih OPTIONS ruta: svaki OPTIONS je preflight.
      final result = preflight ? Response(204) : await next(request);
      // Preuzeta konekcija (npr. WebSocket) nema HTTP odgovor za dopunu.
      if (result is! Response) return result;
      final response = result;

      final allowOrigin = _allowOrigin(
        allowedOrigins,
        request.headers['origin']?.firstOrNull,
      );
      if (allowOrigin == null) return response;

      return response.copyWith(
        headers: response.headers.transform((h) {
          h['Access-Control-Allow-Origin'] = [allowOrigin];
          // Odgovor zavisi od Origin-a: kes ne sme da ga deli izmedju
          // izvora.
          if (allowOrigin != anyOrigin) h['Vary'] = ['Origin'];
          if (preflight) {
            h['Access-Control-Allow-Methods'] = [_allowMethods];
            h['Access-Control-Allow-Headers'] = [_allowHeaders];
            h['Access-Control-Max-Age'] = [_maxAgeSeconds];
          }
        }),
      );
    };

String? _allowOrigin(Set<String> allowed, String? origin) {
  if (allowed.contains(anyOrigin)) return anyOrigin;
  if (origin != null && allowed.contains(origin)) return origin;
  return null;
}
