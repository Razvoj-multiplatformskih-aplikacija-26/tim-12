// Ekran moderacije sobe: tabela predloga + bocni detalj (siri ekrani),
// lista (uzi ekrani). Adrese `/sobe/:roomId` i `/sobe/:roomId/predlog/:id`.
//
// Kretanje tastaturom (bez misa, od ulaza do akcije):
//   ↑/↓ — pomeri izbor (fokus prati izbor, uvek vidljiv kao oznacen red)
//   Delete — ukloni izabrani predlog (uz dijalog potvrde)
//   Esc — ponisti izbor (ili nazad na sobe kad nista nije izabrano)
//
// Napomena za Mac: taster koji na Mac tastaturi pise Delete Flutter vidi
// kao Backspace (Delete je tek Fn+taj taster) — zato brisanje slusa oba.
//
// Izbor zivi u stanju ekrana (ne u adresi): suzavanje prozora i "nazad" sa
// dubinske veze ne gube izbor — adresa je deljiva, izbor je lokalan.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'moderation/keyboard_nav.dart';
import 'moderation/detail_panel.dart';
import 'moderation/room_layouts.dart';
import 'moderation/status_filter.dart';

/// Granica siri/uzak raspored: ispod je lista umesto tabele.
const moderationWideBreakpoint = 900.0;

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key, required this.roomId, this.selectedId});

  final RoomId roomId;

  /// Izbor sa dubinske veze (`/predlog/:id`); null na osnovnoj adresi.
  final ProposalId? selectedId;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  ProposalId? _selectedId;
  StatusFilter _filter = StatusFilter.all;
  bool _sortByVotes = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
  }

  @override
  void didUpdateWidget(ModerationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dubinska veza nosi izbor; povratak na osnovnu adresu ga ne brise.
    if (widget.selectedId != null) _selectedId = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ModerationBloc, ModerationState>(
      listenWhen: (_, state) =>
          state is ModerationLoaded &&
          state.snapshot?.room.id != widget.roomId &&
          state.rooms.any((r) => r.id == widget.roomId),
      listener: (context, _) => context
          .read<ModerationBloc>()
          .add(ModerationRoomOpened(widget.roomId)),
      child: Scaffold(
        appBar: AppBar(
          title: BlocSelector<ModerationBloc, ModerationState, String>(
            selector: (state) => switch (state) {
              ModerationLoaded(:final snapshot) when snapshot != null =>
                snapshot.room.name,
              _ => 'Moderacija',
            },
            builder: (_, title) => Text(title),
          ),
          actions: [
            BlocSelector<ModerationBloc, ModerationState, Room?>(
              selector: (state) => switch (state) {
                ModerationLoaded(:final snapshot) => snapshot?.room,
                _ => null,
              },
              builder: (context, room) => room == null
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: room.status is RoomClosed
                          ? null
                          : () => _confirmCloseRoom(context, room),
                      child: const Text('Zatvori sobu'),
                    ),
            ),
          ],
        ),
        body: BlocBuilder<ModerationBloc, ModerationState>(
          builder: (context, state) => switch (state) {
            ModerationInitial() || ModerationLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            ModerationError() => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Učitavanje nije uspelo.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context
                          .read<ModerationBloc>()
                          .add(ModerationRoomOpened(widget.roomId)),
                      child: const Text('Pokušaj ponovo'),
                    ),
                  ],
                ),
              ),
            ModerationLoaded(:final rooms, :final snapshot, :final tally) =>
              _body(context, rooms, snapshot, tally),
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<Room> rooms,
    RoomSnapshot? snapshot,
    Map<ProposalId, int> tally,
  ) {
    if (!rooms.any((r) => r.id == widget.roomId)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nepoznata soba.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/sobe'),
              child: const Text('Nazad na sobe'),
            ),
          ],
        ),
      );
    }
    if (snapshot == null || snapshot.room.id != widget.roomId) {
      return const Center(child: CircularProgressIndicator());
    }
    final proposals = _visible(snapshot, tally);
    if (proposals.isEmpty) {
      return const Center(child: Text('Nema predloga za ovaj filter.'));
    }
    // Izbor van filtrirane liste ne sme da visi: vrati na prvi red.
    final selected = proposals.any((p) => p.id == _selectedId)
        ? _selectedId
        : proposals.first.id;
    return KeyboardNav(
      proposals: proposals,
      selectedId: selected,
      onSelect: _select,
      onRemove: (id) => _confirmRemoveProposal(context, id),
      onEscape: () {
        if (_selectedId != null) {
          setState(() => _selectedId = null);
        } else {
          context.go('/sobe');
        }
      },
      child: Column(
        children: [
          FilterBar(
            filter: _filter,
            sortByVotes: _sortByVotes,
            onFilter: (f) => setState(() => _filter = f),
            onSort: () => setState(() => _sortByVotes = !_sortByVotes),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= moderationWideBreakpoint
                      ? WideLayout(
                          proposals: proposals,
                          tally: tally,
                          selectedId: selected!,
                          onSelect: _select,
                          onRemove: (id) =>
                              _confirmRemoveProposal(context, id),
                          room: snapshot.room,
                          onCloseRoom: () =>
                              _confirmCloseRoom(context, snapshot.room),
                        )
                      : NarrowLayout(
                          proposals: proposals,
                          tally: tally,
                          selectedId: selected!,
                          onOpen: (id) {
                            final p = proposals.firstWhere(
                              (e) => e.id == id,
                            );
                            setState(() => _selectedId = id);
                            showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              builder: (sheetContext) => SafeArea(
                                child: DetailPanel(
                                  proposal: p,
                                  votes: tally[id] ?? 0,
                                  onRemove: () {
                                    Navigator.pop(sheetContext);
                                    _confirmRemoveProposal(context, id);
                                  },
                                  room: snapshot.room,
                                  onCloseRoom: () {
                                    Navigator.pop(sheetContext);
                                    _confirmCloseRoom(
                                      context,
                                      snapshot.room,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filtrirana (+ opciono sortirana) lista za prikaz. Sort je domenski
  /// poredak glasanja (`compareVotingOrder`, isti kao za pobednika).
  List<Proposal> _visible(RoomSnapshot snapshot, Map<ProposalId, int> tally) {
    final list = snapshot.proposals.where(_filter.matches).toList();
    if (_sortByVotes) {
      list.sort((a, b) => compareVotingOrder(a, b, tally));
    }
    return list;
  }

  void _select(ProposalId id) {
    setState(() => _selectedId = id);
    context.go('/sobe/${widget.roomId.value}/predlog/${id.value}');
  }

  Future<void> _confirmRemoveProposal(
    BuildContext context,
    ProposalId id,
  ) async {
    final bloc = context.read<ModerationBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukloni predlog?'),
        content: const Text(
          'Predlog se trajno uklanja iz glasanja. '
          'Ova akcija ne može da se opozove.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(ModerationProposalRemoved(id));
    }
  }

  Future<void> _confirmCloseRoom(BuildContext context, Room room) async {
    final bloc = context.read<ModerationBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Zatvori sobu „${room.name}“?'),
        content: const Text(
          'Soba se zatvara: predlozi i glasanje staju. '
          'Ova akcija ne može da se opozove.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Zatvori sobu'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(ModerationRoomClosed(room.id));
    }
  }
}

