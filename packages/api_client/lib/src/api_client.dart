// HTTP klijent RadioRoom servera — tanak sloj: poziv + DTO mapiranje.
//
// Radi samo sa `package:http` (bez `dart:io`), pa isti kod radi na VM-u
// (mobilna aplikacija) i u pregledacu (backoffice na vebu). Greska servera
// u `{code, data}` obliku postaje tipizovano `ServerRejected` (bez teksta;
// poruku na srpskom bira aplikacija); mrezni kvar, istek cekanja ili
// odgovor bez koda ostaje genericki `Exception` — Bloc ga tada vodi na
// ekran greske sa "Pokusaj ponovo", bez reloada.
//
// Adresa servera stize `--dart-define=API_BASE_URL=...` pri pokretanju
// (radi i na VM i u pregledacu); podrazumevano lokalni server.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Adresa servera; menja se `--dart-define=API_BASE_URL=<url>` pri
/// pokretanju, bez izmene koda (isti build radi lokalno i na vebu).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// Dobavljac tokena prijave; mesto sastavljanja ga vezuje na bezbedno
/// skladiste platforme (`SecureTokenStore`). Bez tokena server vraca 401,
/// pa Bloc pokazuje genericku gresku sa ponovnim pokusajem.
typedef TokenProvider = Future<String?> Function();

/// Poziv kad server data rutu odbije mrtvom prijavom (401
/// `session_expired` / `unauthenticated`). Mesto sastavljanja kroz njega
/// ubacuje `SessionExpired` u AuthBloc — NE okida se na sam `/auth/login`
/// (pogresna lozinka je `AuthFailure`, ne odjava). Poziv ne sme da baci.
typedef AuthFailureCallback = void Function(ApiError error);

/// Tanak HTTP klijent: poziv + DTO mapiranje, bez UI i bez cuvanja sesije.
final class ApiClient {
  ApiClient({
    required this.baseUrl,
    TokenProvider? tokenProvider,
    AuthFailureCallback? onAuthFailure,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _tokenProvider = tokenProvider,
       _onAuthFailure = onAuthFailure,
       _client = client ?? http.Client();

  /// Osnovna adresa servera (npr. `http://localhost:8080`).
  final String baseUrl;

  /// Najduze cekanje odgovora. Istek (`TimeoutException`) se namerno ne
  /// pretvara u `ServerRejected` — to je tehnicki kvar, ne odbijanje.
  final Duration timeout;

  final TokenProvider? _tokenProvider;
  final AuthFailureCallback? _onAuthFailure;
  final http.Client _client;

  /// `POST /auth/login`: prijava za mobilnu ili backoffice aplikaciju.
  Future<LoginResponse> login({
    required String username,
    required String password,
    AppTarget app = AppTarget.mobile,
  }) async {
    final json = await postJson(
      '/auth/login',
      LoginRequest(
        username: username,
        password: password,
        app: app,
      ).toJson(),
    );
    return LoginResponse.fromJson(json);
  }

  /// `GET /auth/me`: korisnik iz vazece prijave (rehidracija sesije).
  Future<User> me() async =>
      UserDto.fromJson(await getJson('/auth/me')).toDomain();

  /// `POST /auth/logout`: brise prijavu iz koje je poziv stigao.
  /// Odgovor je prazan (204), pa se telo ne cita kao JSON.
  Future<void> logout() async {
    await _send(
      (headers) => _client.post(_uri('/auth/logout'), headers: headers),
      '/auth/logout',
    );
  }

  /// GET sa JSON telom; baca `ServerRejected` ili genericki `Exception`.
  Future<Map<String, Object?>> getJson(String path) async => _asMap(
    await _send(
      (headers) => _client.get(_uri(path), headers: headers),
      path,
    ),
  );

  /// POST sa JSON telom; baca `ServerRejected` ili genericki `Exception`.
  Future<Map<String, Object?>> postJson(
    String path, [
    Map<String, Object?>? body,
  ]) async => _asMap(
    await _send(
      (headers) => _client.post(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      path,
    ),
  );

  Uri _uri(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base$path');
  }

  /// Jedan zahtev: Bearer zaglavlje kad ima tokena, pa dekodiranje.
  /// Mrezni kvar (`ClientException`, `SocketException`) i istek cekanja
  /// (`TimeoutException`) prolaze netaknuti — genericki su `Exception`.
  Future<Object?> _send(
    Future<http.Response> Function(Map<String, String>) send,
    String path,
  ) async {
    final token = await _tokenProvider?.call();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final response = await send(headers).timeout(timeout);
    return _decode(response, path);
  }

  /// Telo uspesnog odgovora; za gresku `{code, data}` baca `ServerRejected`,
  /// za sve ostalo (los oblik, prazno telo, tekst) genericki `Exception`.
  Never _rejected(Map<String, Object?> body) =>
      throw ServerRejected(ApiError.fromJson(body));

  Object? _decode(http.Response response, String path) {
    Object? body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        body = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    if (body is Map && body['code'] is String) {
      final error = ApiError.fromJson(_asMap(body));
      // Mrtva prijava usred rada (401 sa data rute): javlja se vlasniku
      // kroz `onAuthFailure`, a poziv i dalje baca `ServerRejected` svom
      // pozivaocu. Sam login je izuzet — pogresna lozinka ostaje
      // `AuthFailure` u AuthBloc-u, ne odjava.
      if (response.statusCode == 401 &&
          path != '/auth/login' &&
          (error.code == ErrorCodes.sessionExpired ||
              error.code == ErrorCodes.unauthenticated)) {
        _onAuthFailure?.call(error);
      }
      return _rejected(_asMap(body));
    }
    throw Exception('Zahtev nije uspeo (status ${response.statusCode}).');
  }

  /// JSON objekat u `Map<String, Object?>`; sve ostalo je genericka greska.
  Map<String, Object?> _asMap(Object? json) {
    if (json is Map<String, Object?>) return json;
    if (json is Map) {
      return {for (final entry in json.entries) '${entry.key}': entry.value};
    }
    throw Exception('Neocekivan odgovor servera.');
  }
}
