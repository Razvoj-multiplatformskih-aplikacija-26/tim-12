// Tab Pretraga: nadji pesmu pa je predlozi — bez kucanja naslova rucno.
//
// Dva izvora rezultata: (a) postojeci predlozi sobe koji matchuju upit
// ("da li je neko vec predlozio"), sa stanjem i glasanjem; (b) stub
// katalog pesama kojih nema u sobi, sa dugmetom "Predlozi" (prava pretraga
// kataloga stize u KT2). Pravila proverava Bloc domenom: prolaz vodi
// nazad na Glasaj (`onAccepted`), prekrsaj ostaje ovde uz postojeci
// SnackBar sa srpskom porukom. Forma za rucni unos ostaje (link na dnu).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import '../paths.dart';
import 'proposal_labels.dart';
import 'vote_confirmation.dart';

/// Stub katalog za KT1 (bez servera i Spotify API-ja): par pesama kojih
/// nema u demou. Pravila se iz pretrage pokazuju kvotom aktivnih predloga.
const _catalog = [
  Song(title: 'Under Pressure', artist: 'Queen'),
  Song(title: 'Take On Me', artist: 'a-ha'),
  Song(title: 'Superstition', artist: 'Stevie Wonder'),
  Song(title: 'Wonderwall', artist: 'Oasis'),
  Song(title: 'Hips Don\'t Lie', artist: 'Shakira'),
];

class SearchTab extends StatefulWidget {
  const SearchTab({
    super.key,
    required this.focusNode,
    required this.onAccepted,
    required this.currentUser,
  });

  /// Fokus polja: skoljkа ga trazi kad FAB prebaci na ovaj tab.
  final FocusNode focusNode;

  /// Poziva se kad predlog prodje pravila — skoljkа vraca na Glasaj.
  final VoidCallback onAccepted;
  final UserId currentUser;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  String _query = '';
  Song? _pending;
  int? _countBefore;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProposalListBloc, ProposalListState>(
      listenWhen: (_, state) => state is ProposalsLoaded && _pending != null,
      listener: (context, state) {
        final loaded = state as ProposalsLoaded;
        // Prekrsaj pravila: SnackBar je vec prikazan globalno, ostajemo.
        if (loaded.ruleError != null) {
          _pending = null;
          _countBefore = null;
          return;
        }
        // Uspeh: vise predloga nego pre slanja → nazad na glasanje.
        if (_countBefore != null &&
            loaded.snapshot.proposals.length > _countBefore!) {
          _pending = null;
          _countBefore = null;
          widget.onAccepted();
        }
      },
      child: BlocBuilder<ProposalListBloc, ProposalListState>(
        builder: (context, state) => switch (state) {
          ProposalsInitial() || ProposalsLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          ProposalsError() => const Center(
              child: Text('Pretraga trenutno nije dostupna.'),
            ),
          ProposalsEmpty(:final snapshot) => _Results(
            snapshot: snapshot,
            tally: const {},
            query: _query,
            controller: _controller,
            focusNode: widget.focusNode,
            currentUser: widget.currentUser,
            onQuery: (q) => setState(() => _query = q),
            onPropose: (song) => _propose(context, song),
          ),
          ProposalsLoaded(:final snapshot, :final tally) => _Results(
            snapshot: snapshot,
            tally: tally,
            query: _query,
            controller: _controller,
            focusNode: widget.focusNode,
            currentUser: widget.currentUser,
            onQuery: (q) => setState(() => _query = q),
            onPropose: (song) => _propose(context, song),
          ),
        },
      ),
    );
  }

  void _propose(BuildContext context, Song song) {
    final state = context.read<ProposalListBloc>().state;
    _countBefore = switch (state) {
      ProposalsLoaded(:final snapshot) || ProposalsEmpty(:final snapshot) =>
        snapshot.proposals.length,
      _ => null,
    };
    _pending = song;
    context.read<ProposalListBloc>().add(ProposalAdded(song));
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.snapshot,
    required this.tally,
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.currentUser,
    required this.onQuery,
    required this.onPropose,
  });

  final RoomSnapshot snapshot;
  final Map<ProposalId, int> tally;
  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final UserId currentUser;
  final ValueChanged<String> onQuery;
  final ValueChanged<Song> onPropose;

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final existing = q.isEmpty
        ? const <Proposal>[]
        : snapshot.proposals
            .where(
              (p) =>
                  p.song.title.toLowerCase().contains(q) ||
                  p.song.artist.toLowerCase().contains(q),
            )
            .toList();
    // Katalog bez pesama koje su vec u sobi (njih pokriva postojeci deo).
    final catalog = q.isEmpty
        ? const <Song>[]
        : _catalog
            .where(
              (s) =>
                  (s.title.toLowerCase().contains(q) ||
                      s.artist.toLowerCase().contains(q)) &&
                  !snapshot.proposals.any((p) => p.song.isSameSong(s)),
            )
            .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Pretraži pesme',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: onQuery,
        ),
        if (q.isNotEmpty && existing.isEmpty && catalog.isEmpty)
          const ListTile(
            title: Text('Nema pogodaka — predloži ručno ispod.'),
          ),
        if (existing.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Već u sobi'),
          ),
          for (final p in existing)
            _ExistingTile(
              proposal: p,
              votes: tally[p.id] ?? 0,
              isOwn: p.proposedBy == currentUser,
            ),
        ],
        if (catalog.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Predloži novo'),
          ),
          for (final s in catalog)
            ListTile(
              title: Text(s.title),
              subtitle: Text(s.artist),
              trailing: FilledButton.tonal(
                onPressed: () => onPropose(s),
                child: const Text('Predloži'),
              ),
            ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go(
            newProposalPath(snapshot.room.id),
          ),
          child: const Text('ili unesi pesmu ručno'),
        ),
      ],
    );
  }
}

/// Postojeci predlog u rezultatima: stanje + glas kad ima smisla.
class _ExistingTile extends StatelessWidget {
  const _ExistingTile({
    required this.proposal,
    required this.votes,
    required this.isOwn,
  });

  final Proposal proposal;
  final int votes;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.go(proposalPath(proposal.roomId, proposal.id)),
      title: Text(proposal.song.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(proposal.song.artist),
            ProposalStatusChip(proposal.status),
            if (isOwn) const OwnProposalBadge(),
          ],
        ),
      ),
      trailing: proposal.status is InVoting
          ? FilledButton.tonal(
              onPressed: () => confirmVote(context, proposal),
              child: Text('Glasaj · $votes'),
            )
          : Text('$votes'),
    );
  }
}
