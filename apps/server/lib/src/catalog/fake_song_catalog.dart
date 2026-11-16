// Lazni katalog pesama za KT2: isti ugovor kao pravi servis, podaci u
// memoriji, bez mreze — demo i testovi ne zavise od interneta.
//
// Trazi kljuc kao sto bi ga trazio pravi servis: kljuc stize iz `.env`
// (`SONG_CATALOG_API_KEY`) samo na serveru, pa je put kljuca isti kao kad
// stigne prava implementacija.
import 'package:radioroom_domain/radioroom_domain.dart';

import 'song_catalog.dart';

final class FakeSongCatalog implements SongCatalog {
  FakeSongCatalog({required String apiKey, List<Song>? songs})
    : _songs = songs ?? fakeCatalogSongs {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'kljuc kataloga je prazan');
    }
  }

  final List<Song> _songs;

  @override
  Future<List<Song>> search(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _songs
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q),
        )
        .take(limit)
        .toList();
  }
}

/// Link za pustanje: pretraga na YouTube-u (lazni katalog nema prave ID-jeve).
String _youtube(String title, String artist) =>
    'https://www.youtube.com/results?search_query='
    '${Uri.encodeQueryComponent('$artist $title')}';

Song _song(String title, String artist, String album, int seconds) => Song(
  title: title,
  artist: artist,
  album: album,
  durationMs: seconds * 1000,
  externalLink: _youtube(title, artist),
);

/// Pesme laznog kataloga. Ukljucuje pesme iz pocetnih podataka (npr.
/// „Bohemian Rhapsody“, pustena pre 20 min), pa se iz pretrage na odbrani
/// vidi pravilo „nije pustena u poslednjih sat“.
final fakeCatalogSongs = List<Song>.unmodifiable([
  // Iz KT1 stub kataloga mobilne aplikacije.
  _song('Under Pressure', 'Queen', 'Hot Space', 248),
  _song('Take On Me', 'a-ha', 'Hunting High and Low', 225),
  _song('Superstition', 'Stevie Wonder', 'Talking Book', 245),
  _song('Wonderwall', 'Oasis', "(What's the Story) Morning Glory?", 258),
  _song("Hips Don't Lie", 'Shakira', 'Oral Fixation, Vol. 2', 218),
  // Pesme koje vec postoje u pocetnim podacima.
  _song('Bohemian Rhapsody', 'Queen', 'A Night at the Opera', 355),
  _song('Mr. Brightside', 'The Killers', 'Hot Fuss', 222),
  _song('Blinding Lights', 'The Weeknd', 'After Hours', 200),
  _song('Levitating', 'Dua Lipa', 'Future Nostalgia', 203),
  _song('Đurđevdan', 'Bijelo Dugme', 'Ćiribiribela', 260),
  _song('Kiša pada', 'Partibrejkers', 'Kiselo i slatko', 190),
  // Ostalo.
  _song("Don't Stop Me Now", 'Queen', 'Jazz', 209),
  _song('Dancing Queen', 'ABBA', 'Arrival', 231),
  _song('September', 'Earth, Wind & Fire', 'The Best of Vol. 1', 215),
  _song('Uptown Funk', 'Mark Ronson ft. Bruno Mars', 'Uptown Special', 270),
  _song('Get Lucky', 'Daft Punk', 'Random Access Memories', 369),
  _song('Rolling in the Deep', 'Adele', '21', 228),
  _song('Lose Yourself', 'Eminem', '8 Mile', 326),
  _song(
    'Sweet Child O\' Mine',
    "Guns N' Roses",
    'Appetite for Destruction',
    356,
  ),
  _song('Jugoslavija', 'Riblja Čorba', 'Istina', 245),
]);
