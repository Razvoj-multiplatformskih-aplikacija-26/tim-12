// Navigacija: svaki ekran ima svoju adresu (go_router).
//
//   /login                     → prijava (neprijavljen uvek ovde)
//   /                          → preusmerava na /sobe
//   /sobe                      → pocetna: Napravi sobu | Pridruzi se
//   /soba/:roomId              → soba (tabovi: Pretraga | Glasaj | Trenutno)
//   /soba/:roomId/predlog/:id  → detalj predloga
//   /soba/:roomId/novi         → forma novog predloga (rucni unos)
//
// Cuvar ruta cita AuthBloc: neprijavljen vidi samo `/login`, prijavljen se
// sa `/login` vraca na `/sobe`. Tekuci korisnik se cita iz prijavljenog
// stanja — ekrani i Bloc-ovi i dalje dobijaju samo `UserId`, prijava se ne
// prosledjuje kao identitet.
// Soba je u adresi, pa Bloc pravi ShellRoute za sobu iz adrese: svi ekrani
// jedne sobe dele isti Bloc (isti podaci, glas sa detalja vidi i lista).
// Tu je i prikaz prekrsaja pravila (SnackBar), pa se poruka vidi na kom god
// ekranu sobe je akcija pokrenuta.
// Ruter zna samo za PORT — koja implementacija stize, odlucuje `main.dart`.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'auth/login_screen.dart';
import 'home/rooms_screen.dart';
import 'room/proposal/new_proposal_screen.dart';
import 'room/proposal/proposal_detail_screen.dart';
import 'room/room_shell.dart';

GoRouter createRouter({
  required ProposalRepository repository,
  required AuthBloc authBloc,
  VoidCallback? onSimulateError,
  ValueListenable<ThemeMode>? themeMode,
  VoidCallback? onToggleTheme,
}) => GoRouter(
  initialLocation: '/sobe',
  // Svaka promena prijave odmah preusmerava (prijava, odjava, istek).
  refreshListenable: _AuthRefreshListenable(authBloc.stream),
  redirect: (context, state) {
    final authed = authBloc.state is Authenticated;
    final loggingIn = state.matchedLocation == '/login';
    if (!authed) return loggingIn ? null : '/login';
    return loggingIn ? '/sobe' : null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginScreen(app: AppTarget.mobile),
    ),
    GoRoute(path: '/', redirect: (_, _) => '/sobe'),
    // Home: dve kartice (napravi / pridruzi se) nad istim Bloc-om.
    GoRoute(
      path: '/sobe',
      builder: (context, _) => BlocProvider(
        create: (_) => RoomsBloc(
          repository: repository,
          hostId: _currentUser(authBloc),
        )..add(const RoomsRequested()),
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
            currentUser: _currentUser(authBloc),
            currentRole: _currentRole(authBloc),
          )..add(const ProposalsRequested()),
          child: _RuleErrorListener(child: child),
        );
      },
      routes: [
        GoRoute(
          // Skoljka sobe: tabovi Pretraga | Glasaj | Trenutno (swipe + bar).
          path: '/soba/:roomId',
          builder: (_, state) => RoomShell(
            roomId: RoomId(state.pathParameters['roomId']!),
            currentUser: _currentUser(authBloc),
            onSimulateError: onSimulateError,
            themeMode: themeMode,
            onToggleTheme: onToggleTheme,
          ),
          // Pod-rute: lista ostaje ispod forme i detalja, pa "nazad" radi sam.
          routes: [
            GoRoute(
              path: 'novi',
              builder: (_, _) =>
                  NewProposalScreen(currentUser: _currentUser(authBloc)),
            ),
            GoRoute(
              path: 'predlog/:id',
              builder: (_, state) => ProposalDetailScreen(
                proposalId: ProposalId(state.pathParameters['id']!),
                currentUser: _currentUser(authBloc),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const _NotFoundScreen(),
);

/// Tekuci korisnik iz prijavljenog stanja. Cuvar preusmerava neprijavljene
/// na `/login` pre gradnje rute, pa je ovde prijava uvek prisutna.
UserId _currentUser(AuthBloc authBloc) {
  final state = authBloc.state;
  if (state is Authenticated) return state.user.id;
  throw StateError('Ruta sobe bez prijave.');
}

/// Uloga tekuceg korisnika (pravilo povlacenja); isti cuvar kao gore.
Role _currentRole(AuthBloc authBloc) {
  final state = authBloc.state;
  if (state is Authenticated) return state.user.role;
  throw StateError('Ruta sobe bez prijave.');
}

/// Prekrsaj pravila (`ruleError`) i serversko odbijanje (`reason` iz
/// `ProposalsError`) postaju SnackBar sa porukom na srpskom. Tehnicka
/// greska NIJE ovde — nju crta svaki ekran kao ekran greske.
class _RuleErrorListener extends StatelessWidget {
  const _RuleErrorListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<ProposalListBloc, ProposalListState>(
        listenWhen: (_, state) =>
            (state is ProposalsLoaded && state.ruleError != null) ||
            (state is ProposalsError && state.reason != null),
        listener: (context, state) {
          final message = switch (state) {
            ProposalsLoaded(ruleError: final error?) => ruleMessage(error),
            ProposalsError(reason: final reason?) => serverMessage(reason),
            _ => null,
          };
          if (message == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
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

/// Osvezava ruter na svaku promenu prijave (go_router 18 nema vise
/// `GoRouterRefreshStream`, pa je ovo lokalna zamena istih semantika).
final class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
