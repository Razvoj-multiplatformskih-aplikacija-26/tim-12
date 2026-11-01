// Ekran glasanja (tab Glasaj): Winner/Next kartica + lista glasanja.
//
// Ekran samo salje dogadjaje i crta stanje Bloc-a: ne zna za implementaciju
// porta niti racuna pravila. Prikazuje se samo ono o cemu se glasa:
// pobednik (sledeca), predlozi u glasanju sortirani po glasovima i
// predlozeni na cekanju (sklopljeno). Rejected/Removed se ne crtaju nigde.
// Tehnicka greska je ekran greske sa "Pokusaj ponovo"; prekrsaj pravila je
// SnackBar koji prikazuje ruter za celu sobu (pravilo != greska).
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

class ProposalListScreen extends StatelessWidget {
  const ProposalListScreen({
    super.key,
    required this.roomId,
    required this.currentUser,
    this.onSimulateError,
  });

  /// Soba iz adrese.
  final RoomId roomId;

  /// Tekuci korisnik (u KT1 fiksan; u KT2 ga daje prijava) — za oznaku
  /// "Tvoj predlog".
  final UserId currentUser;

  /// Okidac greske sledeceg zahteva. Daje ga mesto sastavljanja aplikacije
  /// (`main.dart`); bez njega stavka menija se ne prikazuje, pa zamena
  /// implementacije porta ne menja ovaj ekran.
  final VoidCallback? onSimulateError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          // Prelaz medju sobama zivi na home-u (/sobe); ovde je samo
          // okidac greske za probu porta.
          if (onSimulateError != null)
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: onSimulateError,
                  child: const ListTile(
                    leading: Icon(Icons.error_outline),
                    title: Text('Simuliraj grešku'),
                  ),
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
          ProposalsError() => const RoomErrorView(),
          ProposalsEmpty() => const _EmptyView(),
          ProposalsLoaded(:final snapshot, :final tally) => _ProposalList(
            snapshot: snapshot,
            tally: tally,
            currentUser: currentUser,
          ),
        },
      ),
      // Bez svog FAB-a: skoljka sobe daje jedan zajednicki (→ Pretraga tab).
    );
  }
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
  const _ProposalList({
    required this.snapshot,
    required this.tally,
    required this.currentUser,
  });

  final RoomSnapshot snapshot;
  final Map<ProposalId, int> tally;
  final UserId currentUser;

  @override
  Widget build(BuildContext context) {
    // Samo ono o cemu se glasa ili ce se glasati: pobednik, u glasanju
    // (sortirano kao tie-break u domenu: glasovi opadajuce, vreme rastuce)
    // i predlozeni na cekanju. Rejected/Removed se ne crtaju nigde.
    final inVoting = snapshot.proposals
        .where((p) => p.status is InVoting)
        .toList()
      ..sort((a, b) {
        final byVotes = (tally[b.id] ?? 0).compareTo(tally[a.id] ?? 0);
        if (byVotes != 0) return byVotes;
        return a.proposedAt.compareTo(b.proposedAt);
      });
    final waiting = snapshot.proposals
        .where((p) => p.status is Proposed)
        .toList();
    final winner = snapshot.proposals.where((p) => p.status is Winner);
    final nowPlaying = currentPlaying(
      proposals: snapshot.proposals,
      now: DateTime.now(),
    );
    return ListView(
      // Mesto ispod poslednjeg reda da ga FAB ne prekrije.
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (winner.isNotEmpty || nowPlaying != null)
          _NextCard(
            winner: winner.firstOrNull,
            nowPlaying: nowPlaying,
          ),
        if (inVoting.isEmpty && waiting.isEmpty)
          const ListTile(
            title: Text('Nema predloga u glasanju.'),
          ),
        for (final p in inVoting)
          _ProposalTile(
            proposal: p,
            votes: tally[p.id] ?? 0,
            isOwn: p.proposedBy == currentUser,
          ),
        if (waiting.isNotEmpty)
          ExpansionTile(
            title: Text('Na čekanju (${waiting.length})'),
            children: [
              for (final p in waiting)
                _ProposalTile(
                  proposal: p,
                  votes: tally[p.id] ?? 0,
                  isOwn: p.proposedBy == currentUser,
                ),
            ],
          ),
      ],
    );
  }
}

/// Kompaktna kartica vrha glasanja: pobednik (sledeca) + sta sada ide.
/// Bez odbrojavanja — ono zivi na tabu Trenutno.
class _NextCard extends StatelessWidget {
  const _NextCard({this.winner, this.nowPlaying});

  final Proposal? winner;
  final Proposal? nowPlaying;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nowPlaying != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: Text(nowPlaying!.song.title),
                subtitle: Text('Sada ide · ${nowPlaying!.song.artist}'),
                onTap: () => context.go(
                  proposalPath(nowPlaying!.roomId, nowPlaying!.id),
                ),
              ),
            if (winner != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(winner!.song.title),
                subtitle: Text('Sledeća · ${winner!.song.artist}'),
                onTap: () => context.go(
                  proposalPath(winner!.roomId, winner!.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    required this.votes,
    required this.isOwn,
  });

  final Proposal proposal;
  final int votes;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final status = proposal.status;
    return ListTile(
      onTap: () => context.go(proposalPath(proposal.roomId, proposal.id)),
      title: Text(proposal.song.title),
      // Wrap: na uskom ekranu cipovi prelaze u novi red umesto da se seku.
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(proposal.song.artist),
            ProposalStatusChip(status),
            if (isOwn) const OwnProposalBadge(),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$votes', style: tabularFigures),
          const SizedBox(width: 4),
          const Icon(Icons.thumb_up_outlined, size: 16),
          // Dugme samo za predloge u glasanju (prikaz); vazenje glasa i
          // dalje proverava domen u Bloc-u (`checkVoteTarget`).
          if (status is InVoting) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => confirmVote(context, proposal),
              child: const Text('Glasaj'),
            ),
          ],
        ],
      ),
    );
  }
}
