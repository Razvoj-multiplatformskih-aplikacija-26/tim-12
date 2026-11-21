// Mesto sastavljanja aplikacije: jedino mesto koje zna koja implementacija
// porta se koristi.
//
// Zamena laznog repozitorijuma (npr. klijentom servera u KT2) menja samo
// ovaj fajl — ruter i ekrani znaju samo za port i Bloc i ne menjaju se.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_api_client/radioroom_api_client.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'router.dart';

void main() {
  // HTTP port: isti Bloc i ekrani, podaci stizu sa servera. Lazni
  // repozitorijum ostaje u `data/` za demo bez servera (njegov `failNext`
  // i dalje radi kao okidac greske sledeceg zahteva).
  final repository = HttpProposalRepository(
    ApiClient(
      baseUrl: apiBaseUrl,
      // TODO(celina 04): token iz bezbednog skladista; do tada server
      // vraca 401 pa Bloc pokazuje genericku gresku sa "Pokusaj ponovo".
      tokenProvider: () async => null,
    ),
  );
  runApp(
    BackofficeApp(
      // Bez laznog repozitorijuma nema okidaca greske: stavka menija se
      // tada ne prikazuje (`onSimulateError` je nullable u ruteru).
      router: createRouter(repository: repository),
    ),
  );
}

class BackofficeApp extends StatelessWidget {
  const BackofficeApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RadioRoom moderacija',
      theme: radioRoomTheme(Brightness.light),
      darkTheme: radioRoomTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
