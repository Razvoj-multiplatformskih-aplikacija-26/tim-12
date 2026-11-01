// Navigacija backoffice-a: svaki ekran ima svoju adresu (go_router).
//
//   /                    → preusmerava na /sobe
//   /sobe                → lista soba (ulazna tacka moderatora)
//   /sobe/:roomId        → predlozi sobe: tabela + bocni detalj
//   /sobe/:roomId/predlog/:id → dubinska veza na isti ekran sa izborom
//
// Jedan ModerationBloc za celu aplikaciju (liste soba + akcije nad svim
// sobama zive u istom stanju). Prekrsaj pravila (`ruleError`) postaje
// SnackBar sa porukom na srpskom — kao u mobilnoj.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import 'ui/moderation_screen.dart';
import 'ui/rooms_screen.dart';

GoRouter createRouter({
  required ProposalRepository repository,
  VoidCallback? onSimulateError,
}) =>
    GoRouter(
      initialLocation: '/sobe',
      routes: [
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
              builder: (_, _) =>
                  RoomsScreen(onSimulateError: onSimulateError),
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
                            '${state.pathParameters['roomId']}/${state.pathParameters['id']}'),
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

/// Prekrsaj pravila (`ruleError`) postaje SnackBar sa porukom na srpskom.
/// Tehnicka greska NIJE ovde — nju crta svaki ekran kao ekran greske.
class _RuleErrorListener extends StatelessWidget {
  const _RuleErrorListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<ModerationBloc, ModerationState>(
        listenWhen: (_, state) =>
            state is ModerationLoaded && state.ruleError != null,
        listener: (context, state) {
          final error = (state as ModerationLoaded).ruleError!;
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
