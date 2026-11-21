// Mesto sastavljanja aplikacije: jedino mesto koje zna koja implementacija
// porta se koristi.
//
// HTTP port: isti Bloc i ekrani, podaci stizu sa servera. Lazni
// repozitorijum ostaje u `data/` za demo bez servera (njegov `failNext`
// i dalje radi kao okidac greske sledeceg zahteva). Token prijave zivi u
// bezbednom skladistu platforme (`SecureTokenStore`); mrtvu prijavu usred
// rada (`onAuthFailure`) mesto sastavljanja ubacuje u AuthBloc kao
// `SessionExpired`, pa cuvar ruta vraca korisnika na prijavu.
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
  runApp(
    BackofficeApp(
      // Bez laznog repozitorijuma nema okidaca greske: stavka menija se
      // tada ne prikazuje (`onSimulateError` je nullable u ruteru).
      router: createRouter(repository: repository, authBloc: authBloc),
      authBloc: authBloc,
    ),
  );
}

class BackofficeApp extends StatelessWidget {
  const BackofficeApp({super.key, required this.router, required this.authBloc});

  final GoRouter router;
  final AuthBloc authBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: authBloc,
      child: MaterialApp.router(
        title: 'RadioRoom moderacija',
        theme: radioRoomTheme(Brightness.light),
        darkTheme: radioRoomTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
