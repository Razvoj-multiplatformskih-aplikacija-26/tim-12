// Port bezbednog skladista tokena — granica izmedju AuthBloc-a i platforme.
//
// Implementacija zivi u aplikaciji (bezbedno skladiste platforme), pa ovaj
// cist Dart paket nikad ne vidi `flutter_secure_storage`. Cuva se samo
// token — lozinka se ne cuva nigde na klijentu.
abstract interface class TokenStore {
  /// Sacuvani token ili null kad sacuvane prijave nema.
  Future<String?> readToken();

  /// Cuva samo token; poziva se posle svake uspesne prijave.
  Future<void> writeToken(String token);

  /// Brise sacuvanu prijavu (odjava, istek sesije).
  Future<void> deleteToken();
}
