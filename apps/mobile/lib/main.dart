// Mesto sastavljanja aplikacije: jedino mesto koje zna koja implementacija
// porta se koristi.
//
// Zamena laznog repozitorijuma (npr. klijentom servera u KT2) menja samo
// ovaj fajl — ekran zna samo za Bloc i ne menja se.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'data/demo_room.dart';
import 'data/fake_proposal_repository.dart';
import 'ui/proposal_list_screen.dart';

void main() {
  runApp(RadioRoomApp(repository: FakeProposalRepository()));
}

class RadioRoomApp extends StatelessWidget {
  const RadioRoomApp({super.key, required this.repository});

  final FakeProposalRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RadioRoom',
      theme: radioRoomTheme(Brightness.light),
      darkTheme: radioRoomTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: BlocProvider(
        create: (_) => ProposalListBloc(
          repository: repository,
          roomId: demoRoomId,
          currentUser: demoUser,
        )..add(const ProposalsRequested()),
        child: ProposalListScreen(
          onSimulateError: () => repository.failNext = true,
        ),
      ),
    );
  }
}
