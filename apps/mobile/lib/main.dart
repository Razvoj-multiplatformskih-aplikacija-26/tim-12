// Mesto sastavljanja aplikacije: jedino mesto koje zna koja implementacija
// porta se koristi.
//
// HTTP port: isti Bloc i ekrani, podaci stizu sa servera. Lazni
// repozitorijum ostaje u `data/` za demo bez servera (njegov `failNext`
// i dalje radi kao okidac greske sledeceg zahteva). Token prijave zivi u
// bezbednom skladistu platforme (`SecureTokenStore`); mrtvu prijavu usred
// rada (`onAuthFailure`) mesto sastavljanja ubacuje u AuthBloc kao
// `SessionExpired`, pa cuvar ruta vraca korisnika na prijavu.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_api_client/radioroom_api_client.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'auth/secure_token_store.dart';
import 'router.dart';

void main() {
  final tokenStore = SecureTokenStore();
  late final AuthBloc authBloc;
  final api = ApiClient(
    baseUrl: apiBaseUrl,
    tokenProvider: tokenStore.readToken,
    onAuthFailure: (_) => authBloc.add(const SessionExpired()),
  );
  final repository = HttpProposalRepository(api);
  authBloc = AuthBloc(
    repository: HttpAuthRepository(api),
    tokenStore: tokenStore,
    // Obnova sacuvane sesije (`GET /auth/me`); bez tokena ili sa mrtvim
    // tokenom cuvar ruta vodi na prijavu.
  )..add(const SessionRestored());
  // Rezim teme zivi ovde (sistemska/svetla/tamna); meni u vrhu sobe ga
  // menja kroz povratni poziv — ekrani i Bloc ga ne znaju.
  final themeMode = ValueNotifier(ThemeMode.system);
  runApp(
    RadioRoomApp(
      router: createRouter(
        repository: repository,
        authBloc: authBloc,
        // Bez laznog repozitorijuma nema okidaca greske: stavka menija se
        // tada ne prikazuje (`onSimulateError` je nullable u ruteru).
        themeMode: themeMode,
        onToggleTheme: () => themeMode.value = _next(themeMode.value),
      ),
      authBloc: authBloc,
      themeMode: themeMode,
    ),
  );
}

/// Prekidac: uvek u suprotnu (svetla <-> tamna). Sistemska se tretira
/// kao svetla, pa prvi klik sa sistemske vodi u tamnu.
ThemeMode _next(ThemeMode mode) =>
    mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

/// Rezervni rezim za testove i preglede bez `main`-a (sistemska tema).
final _fallbackThemeMode = ValueNotifier(ThemeMode.system);

class RadioRoomApp extends StatelessWidget {
  const RadioRoomApp({
    super.key,
    required this.router,
    required this.authBloc,
    this.themeMode,
  });

  final GoRouter router;
  final AuthBloc authBloc;
  final ValueListenable<ThemeMode>? themeMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: authBloc,
      child: ValueListenableBuilder(
        valueListenable: themeMode ?? _fallbackThemeMode,
        builder: (_, mode, _) => MaterialApp.router(
          title: 'RadioRoom',
          theme: radioRoomTheme(Brightness.light),
          darkTheme: radioRoomTheme(Brightness.dark),
          themeMode: mode,
          routerConfig: router,
        ),
      ),
    );
  }
}
