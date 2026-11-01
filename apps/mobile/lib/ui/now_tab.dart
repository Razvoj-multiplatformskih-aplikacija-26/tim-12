// Tab "Trenutno": sta se desava — bez ijedne akcije.
//
// Sadasnja pesma (currentPlaying iz domena) + sledeca (pobednik) +
// odbrojavanje runde i lider. Buduci view mod za veliki ekran u malom.
// Bez svog Scaffold-a: zivi u skoljkci sobe kao i ostali tabovi.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'room_error_view.dart';

class NowTab extends StatelessWidget {
  const NowTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProposalListBloc, ProposalListState>(
      builder: (context, state) => switch (state) {
        ProposalsInitial() || ProposalsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
        ProposalsError() => const RoomErrorView(),
        ProposalsEmpty() => const Center(
            child: Text('Još nema predloga — budi prvi!'),
          ),
        ProposalsLoaded(:final snapshot, :final tally) => _NowView(
            snapshot: snapshot,
            tally: tally,
          ),
      },
    );
  }
}

class _NowView extends StatelessWidget {
  const _NowView({required this.snapshot, required this.tally});

  final RoomSnapshot snapshot;
  final Map<ProposalId, int> tally;

  @override
  Widget build(BuildContext context) {
    final inVoting = snapshot.proposals
        .where((p) => p.status is InVoting)
        .toList()
      ..sort((a, b) {
        final byVotes = (tally[b.id] ?? 0).compareTo(tally[a.id] ?? 0);
        if (byVotes != 0) return byVotes;
        return a.proposedAt.compareTo(b.proposedAt);
      });
    final winners = snapshot.proposals.where((p) => p.status is Winner);
    final now = DateTime.now();
    final current = currentPlaying(
      proposals: snapshot.proposals,
      now: now,
    );
    final left = snapshot.round.endsAt.difference(now);
    final time = left.isNegative
        ? 'Runda je završena'
        : 'još ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    final leader = inVoting.isEmpty
        ? null
        : (tally[inVoting.first.id] ?? 0) > 0
            ? inVoting.first
            : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NowCard(
          icon: Icons.play_circle,
          title: current?.song.title ?? 'Još ništa ne svira',
          subtitle: current == null
              ? 'Čeka se prvi pobednik.'
              : current.song.artist,
        ),
        const SizedBox(height: 8),
        for (final w in winners)
          _NowCard(
            icon: Icons.emoji_events,
            title: w.song.title,
            subtitle: 'Sledeća · pobednik runde',
          ),
        const SizedBox(height: 8),
        _NowCard(
          icon: Icons.how_to_vote,
          title: leader == null
              ? 'Nema predloga u glasanju'
              : 'Vodi ${leader.song.title} (${tally[leader.id] ?? 0})',
          subtitle: 'Glasanje · $time',
        ),
      ],
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );
}
