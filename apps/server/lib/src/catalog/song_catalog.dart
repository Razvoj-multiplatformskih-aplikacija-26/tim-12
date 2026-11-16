// Port spoljnog servisa teme: katalog pesama (pretraga po naslovu ili
// izvodjacu).
//
// Zove ga SAMO server: port je u serveru, a ne u `domain` ili `blocs`, pa ga
// klijent fizicki ne moze pozvati i kljuc servisa nikad ne stize na uredjaj.
// Vraca domenske `Song` objekte — ostatak servera ne zna koji servis stoji
// iza. Za KT2 lazna implementacija ([FakeSongCatalog]); prava (npr. iTunes
// Search ili Spotify) menja samo mesto gde se pravi u `bin/server.dart`.
import 'package:radioroom_domain/radioroom_domain.dart';

abstract interface class SongCatalog {
  /// Pesme ciji naslov ili izvodjac sadrzi [query], najvise [limit].
  /// Baca [CatalogUnavailable] kad servis ne odgovara.
  Future<List<Song>> search(String query, {int limit = 20});
}

/// Spoljni servis nije dostupan (mreza, kvota, kljuc) — klijent dobija
/// `catalog_unavailable`, a ne tehnicki tekst.
final class CatalogUnavailable implements Exception {
  const CatalogUnavailable([this.reason]);

  /// Za log servera; klijentu se ne salje.
  final Object? reason;

  @override
  String toString() => 'CatalogUnavailable($reason)';
}
