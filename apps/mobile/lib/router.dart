// Navigacija: svaki ekran ima svoju adresu (go_router).
//
//   /                          → preusmerava na /sobe
//   /sobe                      → pocetna: Napravi sobu | Pridruzi se
//   /soba/:roomId              → soba (tabovi: Pretraga | Glasaj | Trenutno)
//   /soba/:roomId/predlog/:id  → detalj predloga
//   /soba/:roomId/novi         → forma novog predloga (rucni unos)
//
// Soba je u adresi, pa Bloc pravi ShellRoute za sobu iz adrese: svi ekrani
// jedne sobe dele isti Bloc (isti podaci, glas sa detalja vidi i lista).
// Tu je i prikaz prekrsaja pravila (SnackBar), pa se poruka vidi na kom god
// ekranu sobe je akcija pokrenuta.
// Ruter zna samo za PORT — koja implementacija stize, odlucuje `main.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'ui/new_proposal_screen.dart';
import 'ui/proposal_detail_screen.dart';
import 'ui/proposal_list_screen.dart';
import 'ui/rooms_screen.dart';

GoRouter createRouter({
  required ProposalRepository repository,
  required UserId currentUser,
  Map<RoomId, String> rooms = const {},
  VoidCallback? onSimulateError,
}) => GoRouter(
  initialLocation: '/sobe',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/sobe'),
    // Home: dve kartice (napravi / pridruzi se) nad istim Bloc-om.
    GoRoute(
      path: '/sobe',
      builder: (_, _) => BlocProvider(
        create: (_) => RoomsBloc(repository: repository, hostId: currentUser)
          ..add(const RoomsRequested()),
        child: const RoomsScreen(),
      ),
    ),
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
          child: _RuleErrorListener(child: child),
        );
      },
      routes: [
        GoRoute(
          path: '/soba/:roomId',
          builder: (_, state) => ProposalListScreen(
            roomId: RoomId(state.pathParameters['roomId']!),
            currentUser: currentUser,
            rooms: rooms,
            onSimulateError: onSimulateError,
          ),
          // Pod-rute: lista ostaje ispod forme i detalja, pa "nazad" radi sam.
          routes: [
            GoRoute(
              path: 'novi',
              builder: (_, _) => NewProposalScreen(currentUser: currentUser),
            ),
            GoRoute(
              path: 'predlog/:id',
              builder: (_, state) => ProposalDetailScreen(
                proposalId: ProposalId(state.pathParameters['id']!),
                currentUser: currentUser,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const _NotFoundScreen(),
);

/// Prekrsaj pravila (`ruleError`) postaje SnackBar sa porukom na srpskom.
/// Tehnicka greska NIJE ovde — nju crta svaki ekran kao ekran greske.
class _RuleErrorListener extends StatelessWidget {
  const _RuleErrorListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<ProposalListBloc, ProposalListState>(
        listenWhen: (_, state) =>
            state is ProposalsLoaded && state.ruleError != null,
        listener: (context, state) {
          final error = (state as ProposalsLoaded).ruleError!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(ruleMessage(error))));
        },
        child: child,
      );
}

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
            onPressed: () => context.go('/sobe'),
            child: const Text('Nazad na sobe'),
          ),
        ],
      ),
    ),
  );
}
