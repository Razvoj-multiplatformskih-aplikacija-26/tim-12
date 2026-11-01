// Ekran tehnicke greske sobe — zajednicki za listu i detalj predloga.
//
// Greska ne nosi tekst (standard: poruku bira aplikacija); "Pokusaj ponovo"
// salje `ProposalsRequested`.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';

class RoomErrorView extends StatelessWidget {
  const RoomErrorView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Nešto nije u redu. Proveri vezu i pokušaj ponovo.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.read<ProposalListBloc>().add(
              const ProposalsRequested(),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        ],
      ),
    ),
  );
}
