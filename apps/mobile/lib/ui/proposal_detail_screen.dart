// Detalj jednog predloga (KT1 §1: detalj zapisa na posebnom ekranu).
//
// Nema svoj izvor podataka: cita predlog iz istog Bloc-a kao lista (deli ga
// ShellRoute sobe), pa glas dat ovde lista odmah vidi. Kao i lista, ekran
// samo crta stanje i salje dogadjaje; prekrsaj pravila prikazuje ruter.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import '../paths.dart';
import 'proposal_labels.dart';
import 'room_error_view.dart';
import 'vote_confirmation.dart';

class ProposalDetailScreen extends StatelessWidget {
  const ProposalDetailScreen({
    super.key,
    required this.proposalId,
    required this.currentUser,
  });

  /// Predlog iz adrese.
  final ProposalId proposalId;

  /// Tekuci korisnik (u KT1 fiksan; u KT2 ga daje prijava).
  final UserId currentUser;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Predlog')),
    body: BlocBuilder<ProposalListBloc, ProposalListState>(
      builder: (context, state) => switch (state) {
        ProposalsInitial() ||
        ProposalsLoading() => const Center(child: CircularProgressIndicator()),
        ProposalsError() => const RoomErrorView(),
        ProposalsEmpty(:final snapshot) => _NotFound(roomId: snapshot.room.id),
        ProposalsLoaded(:final snapshot, :final tally) => switch (snapshot
            .proposals
            .where((p) => p.id == proposalId)
            .firstOrNull) {
          null => _NotFound(roomId: snapshot.room.id),
          final proposal => _Details(
            proposal: proposal,
            votes: tally[proposal.id] ?? 0,
            isOwn: proposal.proposedBy == currentUser,
            proposer: proposerLabel(proposal, currentUser),
          ),
        },
      },
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({
    required this.proposal,
    required this.votes,
    required this.isOwn,
    required this.proposer,
  });

  final Proposal proposal;
  final int votes;
  final bool isOwn;
  final String proposer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = proposal.status;
    final link = proposal.song.externalLink;
    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        Text(proposal.song.title, style: text.headlineSmall),
        const SizedBox(height: Spacing.xs),
        Text(proposal.song.artist, style: text.titleMedium),
        const SizedBox(height: Spacing.m),
        Wrap(
          spacing: Spacing.s,
          runSpacing: Spacing.s,
          children: [
            ProposalStatusChip(status),
            if (isOwn) const OwnProposalBadge(),
          ],
        ),
        const SizedBox(height: Spacing.l),
        _InfoRow(
          icon: Icons.person_outline,
          label: 'Predlaže',
          value: proposer,
        ),
        _InfoRow(
          icon: Icons.schedule,
          label: 'Predloženo u',
          value: clockTime(proposal.proposedAt),
        ),
        if (status is Played)
          _InfoRow(
            icon: Icons.play_circle_outline,
            label: 'Puštena u',
            value: clockTime(status.playedAt),
          ),
        _InfoRow(
          icon: Icons.thumb_up_outlined,
          label: 'Glasovi',
          value: '$votes',
        ),
        if (link != null)
          _InfoRow(icon: Icons.link, label: 'Link', value: link),
        // Dugme samo za predloge u glasanju (prikaz); vazenje glasa i dalje
        // proverava domen u Bloc-u (`checkVoteTarget`).
        if (status is InVoting) ...[
          const SizedBox(height: Spacing.xl),
          FilledButton.icon(
            onPressed: () => confirmVote(context, proposal),
            icon: const Icon(Icons.how_to_vote),
            label: const Text('Glasaj'),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    trailing: Text(
      value,
      style: tabularFigures.merge(Theme.of(context).textTheme.bodyLarge),
    ),
  );
}

/// Predlog iz adrese ne postoji u sobi.
class _NotFound extends StatelessWidget {
  const _NotFound({required this.roomId});

  final RoomId roomId;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ovaj predlog ne postoji.'),
          const SizedBox(height: Spacing.l),
          FilledButton(
            onPressed: () => context.go(roomPath(roomId)),
            child: const Text('Nazad na sobu'),
          ),
        ],
      ),
    ),
  );
}
