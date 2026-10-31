// Navigacija: svaki ekran ima svoju adresu (go_router).
//
//   /                          → preusmerava na demo sobu
//   /soba/:roomId              → lista predloga sobe (glavni tok)
//   /soba/:roomId/predlog/:id  → detalj predloga          (M2)
//   /soba/:roomId/novi         → forma novog predloga     (M3)
//
// Soba je u adresi, pa Bloc pravi ShellRoute za sobu iz adrese: svi ekrani
// jedne sobe dele isti Bloc (isti podaci, glas sa detalja vidi i lista).
// Ruter zna samo za PORT — koja implementacija stize, odlucuje `main.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'data/demo_room.dart';
import 'ui/proposal_list_screen.dart';

/// Adresa liste predloga sobe.
String roomPath(RoomId roomId) => '/soba/${roomId.value}';

GoRouter createRouter({
  required ProposalRepository repository,
  required UserId currentUser,
  VoidCallback? onSimulateError,
}) => GoRouter(
  initialLocation: roomPath(demoRoomId),
  routes: [
    GoRoute(path: '/', redirect: (_, _) => roomPath(demoRoomId)),
    ShellRoute(
      builder: (context, state, child) {
        final roomId = RoomId(state.pathParameters['roomId']!);
        // Kljuc po sobi: druga soba u adresi = nov Bloc sa njenim podacima.
        return BlocProvider(
          key: ValueKey(roomId),
          create: (_) => ProposalListBloc(
            repository: repository,
            roomId: roomId,
            currentUser: currentUser,
          )..add(const ProposalsRequested()),
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/soba/:roomId',
          builder: (_, _) =>
              ProposalListScreen(onSimulateError: onSimulateError),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const _NotFoundScreen(),
);

/// Nepoznata adresa.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('RadioRoom')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ova stranica ne postoji.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Nazad na sobu'),
          ),
        ],
      ),
    ),
  );
}
