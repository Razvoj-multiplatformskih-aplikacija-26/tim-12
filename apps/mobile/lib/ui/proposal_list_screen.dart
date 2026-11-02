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
  });

  /// Soba iz adrese.
  final RoomId roomId;

  /// Tekuci korisnik (u KT1 fiksan; u KT2 ga daje prijava) — za oznaku
  /// predloga tekuceg korisnika.
  final UserId currentUser;

  @override
  Widget build(BuildContext context) {
    // Bez svog Scaffold-a i AppBar-a: skoljka sobe daje jedan zajednicki
    // (nazad + naziv + meni) za sva tri taba, kao i FAB.
    return BlocBuilder<ProposalListBloc, ProposalListState>(
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
    // Samo ono o cemu se glasa ili ce se glasati: sledeca pesma (pobednik)
    // na vrhu, predlozi u glasanju sortirani kao tie-break u domenu
    // (glasovi opadajuce, vreme rastuce) i predlozeni na cekanju.
    // Rejected/Removed se ne crtaju nigde.
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
    return ListView(
      // Mesto ispod poslednjeg reda da ga FAB ne prekrije.
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (winner.isNotEmpty) _NextCard(winner: winner.first),
        if (inVoting.isEmpty && waiting.isEmpty)
          const ListTile(
            title: Text('Nema predloga u glasanju.'),
          ),
        for (var i = 0; i < inVoting.length; i++)
          _ProposalTile(
            proposal: inVoting[i],
            votes: tally[inVoting[i].id] ?? 0,
            isOwn: inVoting[i].proposedBy == currentUser,
            ordinal: '${i + 1}',
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
                  ordinal: '–',
                ),
            ],
          ),
      ],
    );
  }
}

/// Sledeca pesma (pobednik) skroz gore, sa ikonicom pobednika.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.winner});

  final Proposal winner;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ListTile(
        leading: const Icon(Icons.emoji_events_outlined),
        title: Text(winner.song.title),
        subtitle: Text('Sledeća · ${winner.song.artist}'),
        onTap: () => context.go(proposalPath(winner.roomId, winner.id)),
      ),
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    required this.votes,
    required this.isOwn,
    required this.ordinal,
  });

  final Proposal proposal;
  final int votes;
  final bool isOwn;

  /// Redni broj u listi glasanja ili crtica za cekanje.
  final String ordinal;

  @override
  Widget build(BuildContext context) {
    final status = proposal.status;
    return ListTile(
      onTap: () => context.go(proposalPath(proposal.roomId, proposal.id)),
      // Redni broj levo od naziva; crtica za predloge na cekanju.
      leading: SizedBox(
        width: 28,
        child: Text(
          ordinal,
          textAlign: TextAlign.center,
          style: tabularFigures,
        ),
      ),
      // Oznake pored naziva kao ikonice (status + tvoj predlog), bez teksta:
      // red ostaje jednoravan, znacenje je na detalju i u tooltip-u.
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              proposal.song.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ProposalStatusIcon(status),
          if (isOwn) ...[
            const SizedBox(width: 4),
            const OwnProposalIcon(),
          ],
        ],
      ),
      subtitle: Text(proposal.song.artist),
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
