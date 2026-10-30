// Pesma — sta se pusta (naslov, izvodjac, link).
//
// Value objekat izdvojen iz `Proposal` (inspiracija Festify `TrackReference` +
// `Metadata`, bez njihovog string-lepljenja): identitet pesme cine
// normalizovan naslov i izvodjac. Spoljni link (npr. YouTube, za KT3
// deep-link pustanje) pripada pesmi, ali NE ulazi u jednakost — ista pesma
// sa dva linka i dalje je ista pesma za pravilo "nije pustena u poslednjih
// sat" (cooldown).
final class Song {
  const Song({
    required this.title,
    required this.artist,
    this.externalLink,
    this.durationMs,
  });

  final String title;
  final String artist;

  /// Spoljni link za pustanje. Opciono u KT1; van jednakosti (vidi ispod).
  final String? externalLink;

  /// Trajanje u milisekundama, opciono — za progress bar u view modu.
  /// Van jednakosti kao i link: trajanje ne menja identitet pesme.
  final int? durationMs;

  /// Ista pesma: poredjenje bez velikih/malih slova i okolnih razmaka, da se
  /// pravilo ne bi zaobilazilo razmakom ("Fuego" vs " fuego ").
  bool isSameSong(Song other) =>
      _normalized(title) == _normalized(other.title) &&
      _normalized(artist) == _normalized(other.artist);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Song && isSameSong(other);

  @override
  int get hashCode => Object.hash(_normalized(title), _normalized(artist));

  @override
  String toString() => 'Song($title — $artist)';
}

String _normalized(String value) => value.trim().toLowerCase();
