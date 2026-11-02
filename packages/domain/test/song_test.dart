// Identitet pesme: samo naslov + izvodjac (normalizovano).
//
// Cover, album i platformski linkovi su prikaz (KT1: samo trenutna pesma
// ih ima) i NE ulaze u jednakost — pravilo "nije pustena u poslednjih
// sat" ne sme da se zaobidje drugacijim coverom ili linkom.
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

void main() {
  test('cover, album i linkovi ne menjaju identitet pesme', () {
    const plain = Song(title: 'Bohemian Rhapsody', artist: 'Queen');
    const rich = Song(
      title: '  bohemian rhapsody ',
      artist: 'QUEEN',
      coverUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
      album: 'A Night at the Opera',
      platformLinks: {'Spotify': 'https://open.spotify.com/track/x'},
    );
    expect(rich, plain);
    expect(rich.hashCode, plain.hashCode);
    expect(rich.isSameSong(plain), isTrue);
  });
}
