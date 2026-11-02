// Mesto sastavljanja aplikacije: jedino mesto koje zna koja implementacija
// porta se koristi.
//
// Zamena laznog repozitorijuma (npr. klijentom servera u KT2) menja samo
// ovaj fajl — ruter i ekrani znaju samo za port i Bloc i ne menjaju se.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'data/demo_room.dart';
import 'data/fake_proposal_repository.dart';
import 'router.dart';

void main() {
  final repository = FakeProposalRepository();
  // Rezim teme zivi ovde (sistemska/svetla/tamna); meni u vrhu sobe ga
  // menja kroz povratni poziv — ekrani i Bloc ga ne znaju.
  final themeMode = ValueNotifier(ThemeMode.system);
  runApp(
    RadioRoomApp(
      router: createRouter(
        repository: repository,
        currentUser: demoUser,
        onSimulateError: () => repository.failNext = true,
        themeMode: themeMode,
        onToggleTheme: () => themeMode.value = _next(themeMode.value),
      ),
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
  const RadioRoomApp({super.key, required this.router, this.themeMode});

  final GoRouter router;
  final ValueListenable<ThemeMode>? themeMode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeMode ?? _fallbackThemeMode,
      builder: (_, mode, _) => MaterialApp.router(
        title: 'RadioRoom',
        theme: radioRoomTheme(Brightness.light),
        darkTheme: radioRoomTheme(Brightness.dark),
        themeMode: mode,
        routerConfig: router,
      ),
    );
  }
}
