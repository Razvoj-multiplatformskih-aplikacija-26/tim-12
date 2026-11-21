// Navigacija backoffice-a: svaki ekran ima svoju adresu (go_router).
//
//   /login                 → prijava (neprijavljen uvek ovde)
//   /                    → preusmerava na /sobe
//   /sobe                → lista soba (ulazna tacka moderatora)
//   /sobe/:roomId        → predlozi sobe: tabela + bocni detalj
//   /sobe/:roomId/predlog/:id → dubinska veza na isti ekran sa izborom
//
// Cuvar ruta cita AuthBloc: neprijavljen vidi samo `/login`, prijavljen se
// sa `/login` vraca na `/sobe`. Prijava uvek salje `AppTarget.backoffice`,
// pa nalog namenjen mobilnoj aplikaciji server odbija, a ekran poruku bira
// iz koda (`serverMessage` nosi `BackofficeNotAllowed` recima).
//
// Jedan ModerationBloc za celu aplikaciju (liste soba + akcije nad svim
// sobama zive u istom stanju). Prekrsaj pravila (`ruleError`) postaje
// SnackBar sa porukom na srpskom — kao u mobilnoj.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'auth/login_screen.dart';
import 'moderation/moderation_screen.dart';
import 'rooms/rooms_screen.dart';

GoRouter createRouter({
  required ProposalRepository repository,
  required AuthBloc authBloc,
  VoidCallback? onSimulateError,
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
      builder: (_, _) => const LoginScreen(app: AppTarget.backoffice),
    ),
    GoRoute(path: '/', redirect: (_, _) => '/sobe'),
    ShellRoute(
      builder: (context, state, child) => BlocProvider(
        create: (_) => ModerationBloc(repository: repository)
          ..add(const ModerationStarted()),
        child: _RuleErrorListener(child: child),
      ),
      routes: [
        GoRoute(
          path: '/sobe',
          builder: (_, _) => RoomsScreen(onSimulateError: onSimulateError),
          routes: [
            GoRoute(
              path: ':roomId',
              builder: (_, state) => ModerationScreen(
                roomId: RoomId(state.pathParameters['roomId']!),
                key: ValueKey(state.pathParameters['roomId']),
              ),
              routes: [
                GoRoute(
                  path: 'predlog/:id',
                  builder: (_, state) => ModerationScreen(
                    roomId: RoomId(state.pathParameters['roomId']!),
                    selectedId: ProposalId(state.pathParameters['id']!),
                    key: ValueKey(
                      '${state.pathParameters['roomId']}/${state.pathParameters['id']}',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => const _NotFoundScreen(),
);

/// Prekrsaj pravila (`ruleError`) i serversko odbijanje (`reason` iz
/// `ModerationError`) postaju SnackBar sa porukom na srpskom. Tehnicka
/// greska NIJE ovde — nju crta svaki ekran kao ekran greske.
class _RuleErrorListener extends StatelessWidget {
  const _RuleErrorListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<ModerationBloc, ModerationState>(
        listenWhen: (_, state) =>
            (state is ModerationLoaded && state.ruleError != null) ||
            (state is ModerationError && state.reason != null),
        listener: (context, state) {
          final message = switch (state) {
            ModerationLoaded(ruleError: final error?) => ruleMessage(error),
            ModerationError(reason: final reason?) => serverMessage(reason),
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
    appBar: AppBar(title: const Text('RadioRoom moderacija')),
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
