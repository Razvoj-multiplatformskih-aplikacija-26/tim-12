// Port prijave — granica izmedju AuthBloc-a i HTTP klijenta.
//
// Implementacija zivi u `radioroom_api_client` (tanke metode nad
// `ApiClient`-om); Bloc i ekrani znaju samo za ovaj port. Greske se
// prijavljuju bacanjem: `ServerRejected` kad server odbije zahtev (razlog
// `{code, data}` iz ugovora, bez teksta) ili genericki `Exception` za
// tehnicki kvar — isto kao kod porta predloga.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'auth_session.dart';

abstract interface class AuthRepository {
  /// Prijava u zadatu aplikaciju; vraca sesiju (korisnik, token, rok).
  Future<AuthSession> login({
    required String username,
    required String password,
    required AppTarget app,
  });

  /// Korisnik iz vazece prijave (`GET /auth/me`). Token je dokumentacija
  /// toka — zaglavlje nosi sacuvani token, identitet iz argumenta se ne
  /// salje niti cita.
  Future<User> me(String token);

  /// Odjava: brise prijavu na serveru (`POST /auth/logout`, best-effort).
  Future<void> logout();
}
