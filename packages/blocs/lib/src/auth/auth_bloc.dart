// Bloc prijave: prijava, obnova sacuvane sesije, odjava i istek sesije.
//
// Klijent nikad ne salje `userId` kao identitet: token putuje u
// `Authorization` zaglavlju (cita ga server iz svoje prijave), a Bloc pamti
// samo korisnika iz odgovora za prikaz. Token se cuva u portu [TokenStore],
// ciju implementaciju daje aplikacija (bezbedno skladiste platforme).
//
// Cuvanje i brisanje tokena su best-effort: bez skladista (npr. Linux bez
// Secret Service) prijava vazi do gasenja aplikacije, a odjava se ne
// zaustavlja kad server odbije poziv (sesija je vec mrtva).
import 'package:bloc/bloc.dart';
import 'package:radioroom_contract/radioroom_contract.dart';

import '../ports/server_rejected.dart';
import 'auth_event.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'token_store.dart';

final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository, required TokenStore tokenStore})
    : _repository = repository,
      _tokenStore = tokenStore,
      super(const AuthInitial()) {
    // Jedan handler za sve dogadjaje, redom (ne paralelno): kasni odgovor
    // obnove sesije ne moze da pregazi svezu prijavu ili odjavu.
    on<AuthEvent>(
      (event, emit) => switch (event) {
        LoginRequested(:final username, :final password, :final app) => _onLogin(
          username: username,
          password: password,
          app: app,
          emit: emit,
        ),
        LogoutRequested() => _onLogout(emit),
        SessionRestored() => _onRestored(emit),
        SessionExpired() => _onExpired(emit),
      },
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final AuthRepository _repository;
  final TokenStore _tokenStore;

  Future<void> _onLogin({
    required String username,
    required String password,
    required AppTarget app,
    required Emitter<AuthState> emit,
  }) async {
    emit(const AuthLoading());
    try {
      final session = await _repository.login(
        username: username,
        password: password,
        app: app,
      );
      await _tokenStore.writeToken(session.token).catchError((Object _) {});
      emit(Authenticated(session.user));
    } on ServerRejected catch (rejected) {
      // Pogresna lozinka ili zabranjena aplikacija: razlog nosi stanje,
      // bez odjave — ovo nije istek sesije.
      emit(AuthFailure(rejected.error));
    } on Exception {
      emit(const AuthFailure(ApiError(code: ErrorCodes.unknown)));
    }
  }

  Future<void> _onRestored(Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final token = await _tokenStore.readToken().catchError((Object _) => null);
    if (token == null || token.isEmpty) {
      emit(const Unauthenticated());
      return;
    }
    try {
      emit(Authenticated(await _repository.me(token)));
    } on ServerRejected catch (rejected) {
      // Mrtva prijava (istekla, povucena odjavom) vodi na prijavu bez
      // poruke o gresci; ostala odbijanja (npr. blokiran nalog) nose razlog.
      if (rejected.error.code == ErrorCodes.sessionExpired ||
          rejected.error.code == ErrorCodes.unauthenticated) {
        await _tokenStore.deleteToken().catchError((Object _) {});
        // Istekla prijava se kaze korisniku; povucena (odjava na drugom
        // mestu, nepoznat token) samo vodi na prijavu.
        emit(
          Unauthenticated(
            expired: rejected.error.code == ErrorCodes.sessionExpired,
          ),
        );
      } else {
        emit(AuthFailure(rejected.error));
      }
    } on Exception {
      emit(const AuthFailure(ApiError(code: ErrorCodes.unknown)));
    }
  }

  Future<void> _onLogout(Emitter<AuthState> emit) async {
    // Best-effort: odjava uspeva i kad server odbije poziv (npr. istekla
    // sesija) — sacuvana prijava se svakako brise. try/catch umesto
    // catchError: hvata i sinhrono bacanje mock-ovanog porta u testovima.
    try {
      await _repository.logout();
    } on Exception {
      // Namerno se guta: lokalna odjava ne zavisi od servera.
    }
    await _tokenStore.deleteToken().catchError((Object _) {});
    emit(const Unauthenticated());
  }

  Future<void> _onExpired(Emitter<AuthState> emit) async {
    // Server je odbacio token usred rada (401 sa data rute): sacuvana
    // prijava se brise, cuvar ruta vraca ekran na prijavu, a ekran prijave
    // kaze da je istekla.
    await _tokenStore.deleteToken().catchError((Object _) {});
    emit(const Unauthenticated(expired: true));
  }
}
