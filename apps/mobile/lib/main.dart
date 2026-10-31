// Mesto sastavljanja aplikacije: jedino mesto koje zna koja implementacija
// porta se koristi.
//
// Zamena laznog repozitorijuma (npr. klijentom servera u KT2) menja samo
// ovaj fajl — ruter i ekrani znaju samo za port i Bloc i ne menjaju se.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'data/demo_room.dart';
import 'data/fake_proposal_repository.dart';
import 'router.dart';

void main() {
  final repository = FakeProposalRepository();
  runApp(
    RadioRoomApp(
      router: createRouter(
        repository: repository,
        currentUser: demoUser,
        onSimulateError: () => repository.failNext = true,
      ),
    ),
  );
}

class RadioRoomApp extends StatelessWidget {
  const RadioRoomApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RadioRoom',
      theme: radioRoomTheme(Brightness.light),
      darkTheme: radioRoomTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
