// JSON odgovori servera.
//
// Privremeno: oblik greske `{code, data}` je dogovoren za zajednicki paket
// ugovora (`packages/contract`); kad stigne, ove funkcije koriste njegove
// tipove umesto rucnih mapa.
import 'dart:convert';

import 'package:relic/relic.dart';

/// Odgovor sa JSON telom.
Response jsonResponse(Object? body, {int status = 200}) => Response(
  status,
  body: Body.fromString(jsonEncode(body), mimeType: MimeType.json),
);

/// Greska: kod i podaci pravila. Poruku za korisnika pravi klijent iz koda,
/// zato server ne salje tekst.
Response errorResponse(
  int status,
  String code, [
  Map<String, Object?> data = const {},
]) => jsonResponse({'code': code, 'data': data}, status: status);

/// Cita JSON objekat iz tela zahteva; `null` kad telo nije JSON objekat.
Future<Map<String, Object?>?> readJsonObject(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}
