// Katalog pesama: lazna implementacija porta (bez baze) i ruta pretrage nad
// pravim serverom (sa bazom), ukljucujuci servis koji ne radi ili ne odgovara.
import 'dart:async';
import 'dart:convert';

import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_server/radioroom_server.dart';
import 'package:test/test.dart';

import 'support/test_server.dart';

/// Servis koji uvek javlja da nije dostupan.
final class _DownCatalog implements SongCatalog {
  @override
  Future<List<Song>> search(String query, {int limit = 20}) async =>
      throw const CatalogUnavailable('kvota');
}

/// Servis koji nikad ne odgovori.
final class _HangingCatalog implements SongCatalog {
  @override
  Future<List<Song>> search(String query, {int limit = 20}) =>
      Completer<List<Song>>().future;
}

void main() {
  group('FakeSongCatalog', () {
    final catalog = FakeSongCatalog(apiKey: 'kljuc');

    test('trazi po naslovu bez obzira na velika slova i razmake', () async {
      final songs = await catalog.search('  bohemian ');

      expect(songs.map((s) => s.title), ['Bohemian Rhapsody']);
    });

    test('trazi i po izvodjacu', () async {
      final songs = await catalog.search('the killers');

      expect(songs.map((s) => s.title), ['Mr. Brightside']);
    });

    test('jedan upit nalazi i po naslovu i po izvodjacu', () async {
      final songs = await catalog.search('queen');

      // Tri pesme grupe Queen i „Dancing Queen“ (ABBA) po naslovu.
      expect(songs.map((s) => s.title), [
        'Under Pressure',
        'Bohemian Rhapsody',
        "Don't Stop Me Now",
        'Dancing Queen',
      ]);
    });

    test('postuje limit', () async {
      expect(await catalog.search('e', limit: 2), hasLength(2));
    });

    test('nista ne nalazi za prazan upit ili nepostojecu pesmu', () async {
      expect(await catalog.search('   '), isEmpty);
      expect(await catalog.search('nepostojeca pesma xyz'), isEmpty);
    });

    test('pesme imaju trajanje, album i link za pustanje', () async {
      final song = (await catalog.search('take on me')).single;

      expect(song.durationMs, greaterThan(0));
      expect(song.album, isNotEmpty);
      expect(song.externalLink, startsWith('https://'));
    });

    test('bez kljuca se ne pravi', () {
      expect(() => FakeSongCatalog(apiKey: ' '), throwsArgumentError);
    });
  });

  group('GET /catalog/search', () {
    test('trazi prijavu', () async {
      final server = await startTestServer();
      if (server == null) return;

      final response = await server.get('/catalog/search?q=queen');

      expect(response.statusCode, 401);
    });

    test('vraca pesme iz kataloga', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.get(
        '/catalog/search?q=Bohemian',
        token: token,
      );

      expect(response.statusCode, 200);
      final songs = (jsonDecode(response.body) as Map)['songs'] as List;
      expect(songs, hasLength(1));
      expect(songs.single, {
        'title': 'Bohemian Rhapsody',
        'artist': 'Queen',
        'album': 'A Night at the Opera',
        'durationMs': 355000,
        'externalLink': startsWith('https://www.youtube.com/'),
      });
    });

    test('nista nadjeno je 200 sa praznim spiskom', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.get('/catalog/search?q=xyz', token: token);

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), {'songs': <Object?>[]});
    });

    test('prazan ili predug upit je 400', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      for (final path in [
        '/catalog/search',
        '/catalog/search?q=%20%20',
        '/catalog/search?q=${'a' * (maxQueryLength + 1)}',
      ]) {
        final response = await server.get(path, token: token);
        expect(response.statusCode, 400, reason: path);
        expect(jsonDecode(response.body), {'code': 'bad_request', 'data': {}});
      }
    });

    test(
      'servis ne radi: 503 catalog_unavailable, bez tehnickog teksta',
      () async {
        final server = await startTestServer(catalog: _DownCatalog());
        if (server == null) return;
        final token = await server.login('ana');

        final response = await server.get('/catalog/search?q=x', token: token);

        expect(response.statusCode, 503);
        expect(jsonDecode(response.body), {
          'code': 'catalog_unavailable',
          'data': {},
        });
      },
    );

    test(
      'servis ne odgovara: posle roka 503, a ne ucitavanje bez kraja',
      () async {
        final server = await startTestServer(
          catalog: _HangingCatalog(),
          catalogTimeout: const Duration(milliseconds: 100),
        );
        if (server == null) return;
        final token = await server.login('ana');

        final response = await server.get('/catalog/search?q=x', token: token);

        expect(response.statusCode, 503);
        expect(
          (jsonDecode(response.body) as Map)['code'],
          'catalog_unavailable',
        );
      },
    );
  });
}
