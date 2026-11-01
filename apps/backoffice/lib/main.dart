// Mesto sastavljanja aplikacije: jedino mesto koje zna koja implementacija
// porta se koristi.
//
// Zamena laznog repozitorijuma (npr. klijentom servera u KT2) menja samo
// ovaj fajl — ruter i ekrani znaju samo za port i Bloc i ne menjaju se.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'data/fake_moderation_repository.dart';
import 'router.dart';

void main() {
  final repository = FakeModerationRepository();
  runApp(
    BackofficeApp(
      router: createRouter(
        repository: repository,
        onSimulateError: () => repository.failNext = true,
      ),
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
