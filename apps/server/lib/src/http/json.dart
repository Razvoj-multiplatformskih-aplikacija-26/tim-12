// JSON odgovori servera.
//
// Greska je uvek `ApiError` iz zajednickog ugovora (`{code, data}`, bez
// teksta), a HTTP status za kod daje `ErrorCodes.httpStatus` — server ga ne
// bira sam, pa isti kod uvek ima isti status.
import 'dart:convert';

import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:relic/relic.dart';

/// Odgovor sa JSON telom.
Response jsonResponse(Object? body, {int status = 200}) => Response(
  status,
  body: Body.fromString(jsonEncode(body), mimeType: MimeType.json),
);

/// Greska iz ugovora. Poruku za korisnika pravi klijent iz koda, zato
/// server ne salje tekst.
Response apiErrorResponse(ApiError error) =>
    jsonResponse(error.toJson(), status: ErrorCodes.httpStatus(error.code));

/// Greska sa kodom iz [ErrorCodes] i opcionim podacima.
Response errorResponse(String code, [Map<String, Object?> data = const {}]) =>
    apiErrorResponse(ApiError(code: code, data: data));

/// Cita JSON objekat iz tela zahteva; `null` kad telo nije JSON objekat.
Future<Map<String, Object?>?> readJsonObject(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Telo zahteva kao DTO iz ugovora: [parse] je `fromJson` tog DTO-a.
/// `null` kad telo nije JSON objekat ili ne odgovara ugovoru — ruta tada
/// vraca `bad_request`.
Future<T?> readRequest<T>(
  Request request,
  T Function(Map<String, Object?> json) parse,
) async {
  final json = await readJsonObject(request);
  if (json == null) return null;
  try {
    return parse(json);
  } on FormatException {
    return null;
  }
}
