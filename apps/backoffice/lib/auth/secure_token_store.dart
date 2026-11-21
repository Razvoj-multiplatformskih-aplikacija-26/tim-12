// Bezbedno skladiste tokena (implementacija porta `TokenStore`).
//
// Cuva se samo token (`radioroom_token`) — lozinka se nikad ne cuva.
// Na Linux desktopu upis ide preko Secret Service (libsecret) sistemskog
// korisnika; na sistemu bez njega upis ne uspeva, pa prijava tada vazi
// samo do gasenja aplikacije (AuthBloc cuvanje tretira kao best-effort).
// U pregledacu upis ide u zasifrovano skladiste pregledaca. Na macOS-u
// token ide u korisnikov login Keychain (`useDataProtectionKeyChain:
// false`): Data Protection Keychain trazi `keychain-access-groups`, a to
// pravo traze potpis razvojnim sertifikatom, pa se aplikacija bez njega ne
// bi ni izgradila.
// Nista se ne instalira iz koda.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';

/// Kljuc pod kojim token zivi u skladistu platforme.
const secureTokenKey = 'radioroom_token';

final class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: secureTokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: secureTokenKey, value: token);

  @override
  Future<void> deleteToken() => _storage.delete(key: secureTokenKey);
}
