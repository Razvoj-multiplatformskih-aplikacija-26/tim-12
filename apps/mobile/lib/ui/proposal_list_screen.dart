// Ekran glavnog toka slusaoca: 4 stanja (ucitavanje / greska / prazno /
// podaci), predlog pesme i glas.
//
// Ekran samo salje dogadjaje i crta stanje Bloc-a: ne zna za implementaciju
// porta niti racuna pravila. Prekrsaj pravila (`ruleError`) je SnackBar,
// tehnicka greska je ekran greske sa "Pokusaj ponovo" (pravilo != greska).
// Privremen do celine "mobilna aplikacija" (go_router, tema, ikonica).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'proposal_status_label.dart';
import 'rule_messages.dart';

class ProposalListScreen extends StatelessWidget {
  const ProposalListScreen({super.key, this.onSimulateError});

  /// Okidac greske sledeceg zahteva. Daje ga mesto sastavljanja aplikacije
  /// (`main.dart`); bez njega stavka menija se ne prikazuje, pa zamena
  /// implementacije porta ne menja ovaj ekran.
  final VoidCallback? onSimulateError;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProposalListBloc, ProposalListState>(
      listenWhen: (_, state) =>
          state is ProposalsLoaded && state.ruleError != null,
      listener: (context, state) {
        final error = (state as ProposalsLoaded).ruleError!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(ruleMessage(error))));
      },
      child: Scaffold(
        appBar: AppBar(
          title: BlocSelector<ProposalListBloc, ProposalListState, String>(
            selector: (state) => switch (state) {
              ProposalsLoaded(:final snapshot) ||
              ProposalsEmpty(:final snapshot) => snapshot.room.name,
              _ => 'RadioRoom',
            },
            builder: (_, title) => Text(title),
          ),
          actions: [
            if (onSimulateError != null)
              PopupMenuButton<void>(
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onSimulateError,
                    child: const Text('Simuliraj grešku'),
                  ),
                ],
              ),
          ],
        ),
        body: BlocBuilder<ProposalListBloc, ProposalListState>(
          builder: (context, state) => switch (state) {
            ProposalsInitial() || ProposalsLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            ProposalsError() => const _ErrorView(),
            ProposalsEmpty() => const _EmptyView(),
            ProposalsLoaded(:final snapshot, :final tally) => _ProposalList(
              snapshot: snapshot,
              tally: tally,
            ),
          },
        ),
        floatingActionButton:
            BlocSelector<ProposalListBloc, ProposalListState, bool>(
              selector: (state) =>
                  state is ProposalsLoaded || state is ProposalsEmpty,
              builder: (context, canPropose) => canPropose
                  ? FloatingActionButton.extended(
                      onPressed: () => _propose(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Predloži pesmu'),
                    )
                  : const SizedBox.shrink(),
            ),
      ),
    );
  }

  Future<void> _propose(BuildContext context) async {
    final bloc = context.read<ProposalListBloc>();
    final song = await showDialog<Song>(
      context: context,
      builder: (_) => const _ProposeDialog(),
    );
    if (song != null) bloc.add(ProposalAdded(song));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music, size: 48),
          SizedBox(height: 16),
          Text('Još nema predloga — budi prvi!', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ProposalList extends StatelessWidget {
  const _ProposalList({required this.snapshot, required this.tally});

  final RoomSnapshot snapshot;
  final Map<ProposalId, int> tally;

  @override
  Widget build(BuildContext context) {
    final proposals = snapshot.proposals;
    return ListView.builder(
      // Mesto ispod poslednjeg reda da ga FAB ne prekrije.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: proposals.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Runda traje do ${_clockTime(snapshot.round.endsAt)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        final p = proposals[index - 1];
        return _ProposalTile(proposal: p, votes: tally[p.id] ?? 0);
      },
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({required this.proposal, required this.votes});

  final Proposal proposal;
  final int votes;

  @override
  Widget build(BuildContext context) {
    final status = proposal.status;
    return ListTile(
      title: Text(proposal.song.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Flexible(child: Text(proposal.song.artist)),
            const SizedBox(width: 8),
            ProposalStatusChip(status),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$votes',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.thumb_up_outlined, size: 16),
          // Dugme samo za predloge u glasanju (prikaz); vazenje glasa i
          // dalje proverava domen u Bloc-u (`checkVoteTarget`).
          if (status is InVoting) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _vote(context),
              child: const Text('Glasaj'),
            ),
          ],
        ],
      ),
    );
  }

  /// Glas je nepovratan, pa trazi potvrdu u dijalogu.
  Future<void> _vote(BuildContext context) async {
    final bloc = context.read<ProposalListBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Glasati za „${proposal.song.title}“?'),
        content: const Text('Glas u rundi se ne može promeniti.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Glasaj'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(VoteCast(proposal.id));
  }
}

/// Minimalni unos predloga (puna forma stize u celini "mobilna aplikacija").
class _ProposeDialog extends StatefulWidget {
  const _ProposeDialog();

  @override
  State<_ProposeDialog> createState() => _ProposeDialogState();
}

class _ProposeDialogState extends State<_ProposeDialog> {
  final _title = TextEditingController();
  final _artist = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final artist = _artist.text.trim();
    if (title.isEmpty || artist.isEmpty) return;
    Navigator.pop(context, Song(title: title, artist: artist));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Predloži pesmu'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Naslov'),
          textInputAction: TextInputAction.next,
        ),
        TextField(
          controller: _artist,
          decoration: const InputDecoration(labelText: 'Izvođač'),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Otkaži'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Predloži')),
    ],
  );
}

String _clockTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';
