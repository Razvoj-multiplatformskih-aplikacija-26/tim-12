// Pretraga kataloga: `GET /catalog/search?q=…` (trazi prijavu, kao svaka
// ruta van `publicPaths`).
//
// Server je jedini koji zove spoljni servis; klijent dobija samo pesme ili
// kod greske. Poziv porta ima rok: spor servis ne sme da drzi klijenta u
// ucitavanju bez kraja — posle roka klijent dobija `catalog_unavailable`.
import 'dart:async';
import 'dart:io';

import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mapping/radioroom_mapping.dart';
import 'package:relic/relic.dart';

import '../http/json.dart';
import 'song_catalog.dart';

/// Najduzi upit; duzi je greska klijenta, ne pretraga.
const maxQueryLength = 100;

final class CatalogRoutes {
  CatalogRoutes({
    required this.catalog,
    this.timeout = const Duration(seconds: 5),
  });

  final SongCatalog catalog;

  /// Koliko server ceka spoljni servis.
  final Duration timeout;

  void mount(RelicApp app) {
    app.get('/catalog/search', search);
  }

  /// `q` je obavezan i nije prazan; prazan rezultat je `200` sa `[]`.
  Future<Response> search(Request request) async {
    final query = request.url.queryParameters['q']?.trim() ?? '';
    if (query.isEmpty || query.length > maxQueryLength) {
      return errorResponse(ErrorCodes.badRequest);
    }

    final List<Song> songs;
    try {
      songs = await catalog.search(query).timeout(timeout);
    } on Object catch (error) {
      // CatalogUnavailable, istek roka ili bilo koja greska servisa: razlog
      // ide u log servera, klijent dobija samo kod.
      stderr.writeln('Katalog nije dostupan: $error');
      return errorResponse(ErrorCodes.catalogUnavailable);
    }
    return jsonResponse(
      CatalogSearchResponse(songs: [for (final song in songs) song.toDto()])
          .toJson(),
    );
  }
}
