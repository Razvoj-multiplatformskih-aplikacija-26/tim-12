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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

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
  _StatusFilter _filter = _StatusFilter.all;
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
            ModerationLoaded(:final rooms, :final snapshot) =>
              _body(context, rooms, snapshot),
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<Room> rooms,
    RoomSnapshot? snapshot,
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
    final loaded = context.read<ModerationBloc>().state as ModerationLoaded;
    final proposals = _visible(snapshot, loaded.tally);
    if (proposals.isEmpty) {
      return const Center(child: Text('Nema predloga za ovaj filter.'));
    }
    // Izbor van filtrirane liste ne sme da visi: vrati na prvi red.
    final selected = proposals.any((p) => p.id == _selectedId)
        ? _selectedId
        : proposals.first.id;
    return _KeyboardNav(
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
          _FilterBar(
            filter: _filter,
            sortByVotes: _sortByVotes,
            onFilter: (f) => setState(() => _filter = f),
            onSort: () => setState(() => _sortByVotes = !_sortByVotes),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= moderationWideBreakpoint
                      ? _WideLayout(
                          proposals: proposals,
                          tally: loaded.tally,
                          selectedId: selected!,
                          onSelect: _select,
                          onRemove: (id) =>
                              _confirmRemoveProposal(context, id),
                          room: snapshot.room,
                          onCloseRoom: () =>
                              _confirmCloseRoom(context, snapshot.room),
                        )
                      : _NarrowLayout(
                          proposals: proposals,
                          tally: loaded.tally,
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
                                child: _DetailPanel(
                                  proposal: p,
                                  votes: loaded.tally[id] ?? 0,
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

  /// Filtrirana (+ opciono sortirana) lista za prikaz.
  List<Proposal> _visible(RoomSnapshot snapshot, Map<ProposalId, int> tally) {
    final list = snapshot.proposals.where(_filter.matches).toList();
    if (_sortByVotes) {
      list.sort((a, b) {
        final byVotes = (tally[b.id] ?? 0).compareTo(tally[a.id] ?? 0);
        if (byVotes != 0) return byVotes;
        return a.proposedAt.compareTo(b.proposedAt);
      });
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

/// Filter predloga po stanju (minimum za moderaciju: odvoji aktivne od
/// zavrsenih). Vrednost zivi u stanju ekrana — menja samo prikaz, ne podatke.
enum _StatusFilter { all, active, finished }

extension on _StatusFilter {
  bool matches(Proposal p) => switch (this) {
        _StatusFilter.all => true,
        _StatusFilter.active => p.isActive,
        _StatusFilter.finished => !p.isActive,
      };

  String get label => switch (this) {
        _StatusFilter.all => 'Svi',
        _StatusFilter.active => 'Aktivni',
        _StatusFilter.finished => 'Završeni',
      };
}

/// Traka filtera i sortiranja iznad liste: menja samo prikaz, ne podatke.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.sortByVotes,
    required this.onFilter,
    required this.onSort,
  });

  final _StatusFilter filter;
  final bool sortByVotes;
  final ValueChanged<_StatusFilter> onFilter;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<_StatusFilter>(
            segments: [
              for (final f in _StatusFilter.values)
                ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {filter},
            onSelectionChanged: (set) => onFilter(set.single),
          ),
          TextButton.icon(
            onPressed: onSort,
            icon: Icon(sortByVotes ? Icons.arrow_downward : Icons.sort),
            label: const Text('Glasovi'),
          ),
        ],
      ),
    );
  }
}

/// Tastatura ekrana: strelice selektuju, Delete uklanja, Esc izlazi.
/// Omotac drzi `autofocus` da tasteri rade odmah po ulazu, bez klika misem.
class _KeyboardNav extends StatelessWidget {
  const _KeyboardNav({
    required this.proposals,
    required this.selectedId,
    required this.onSelect,
    required this.onRemove,
    required this.onEscape,
    required this.child,
  });

  final List<Proposal> proposals;
  final ProposalId? selectedId;
  final ValueChanged<ProposalId> onSelect;
  final ValueChanged<ProposalId> onRemove;
  final VoidCallback onEscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.delete): _RemoveIntent(),
        // Mac: taster sa oznakom Delete salje Backspace.
        SingleActivator(LogicalKeyboardKey.backspace): _RemoveIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _EscapeIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) => _move(intent.delta),
          ),
          _RemoveIntent: CallbackAction<_RemoveIntent>(
            onInvoke: (_) {
              final id = selectedId;
              if (id != null) onRemove(id);
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              onEscape();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  void _move(int delta) {
    if (proposals.isEmpty) return;
    final current = proposals.indexWhere((p) => p.id == selectedId);
    final next = (current < 0 ? 0 : (current + delta + proposals.length)) %
        proposals.length;
    onSelect(proposals[next].id);
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);

  final int delta;
}

class _RemoveIntent extends Intent {
  const _RemoveIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

/// Siri raspored: tabela levo, detalj u bocnom panelu desno.
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.proposals,
    required this.tally,
    required this.selectedId,
    required this.onSelect,
    required this.onRemove,
    required this.room,
    required this.onCloseRoom,
  });

  final List<Proposal> proposals;
  final Map<ProposalId, int> tally;
  final ProposalId selectedId;
  final ValueChanged<ProposalId> onSelect;
  final ValueChanged<ProposalId> onRemove;
  final Room room;
  final VoidCallback onCloseRoom;

  @override
  Widget build(BuildContext context) {
    final selected = proposals.firstWhere((p) => p.id == selectedId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _ProposalTable(
              proposals: proposals,
              tally: tally,
              selectedId: selectedId,
              onSelect: onSelect,
              onRemove: onRemove,
            ),
          ),
        ),
        SizedBox(
          width: 360,
          child: _DetailPanel(
            proposal: selected,
            votes: tally[selectedId] ?? 0,
            onRemove: () => onRemove(selectedId),
            room: room,
            onCloseRoom: onCloseRoom,
          ),
        ),
      ],
    );
  }
}

/// Uzak raspored: lista umesto tabele; tap obelezi red i otvori detalj u
/// donjem sheet-u sa istim akcijama kao bocni panel (nema navigacije —
/// adresa ostaje na sobi, izbor zivi u stanju ekrana). Tastatura i dalje
/// samo pomera izbor, bez sheet-a; "nazad" se vraca bez gubitka izbora.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.proposals,
    required this.tally,
    required this.selectedId,
    required this.onOpen,
  });

  final List<Proposal> proposals;
  final Map<ProposalId, int> tally;
  final ProposalId selectedId;

  /// Tap na red: obelezi + otvori detalj (roditelj pokazuje sheet).
  final ValueChanged<ProposalId> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: proposals.length,
      itemBuilder: (context, index) {
        final p = proposals[index];
        return ListTile(
          selected: p.id == selectedId,
          selectedTileColor:
              Theme.of(context).colorScheme.secondaryContainer,
          title: Text(p.song.title),
          subtitle: Text(p.song.artist),
          trailing: Text('${tally[p.id] ?? 0}'),
          onTap: () => onOpen(p.id),
        );
      },
    );
  }
}

class _ProposalTable extends StatelessWidget {
  const _ProposalTable({
    required this.proposals,
    required this.tally,
    required this.selectedId,
    required this.onSelect,
    required this.onRemove,
  });

  final List<Proposal> proposals;
  final Map<ProposalId, int> tally;
  final ProposalId selectedId;
  final ValueChanged<ProposalId> onSelect;
  final ValueChanged<ProposalId> onRemove;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      showCheckboxColumn: false,
      columns: const [
        DataColumn(label: Text('Pesma')),
        DataColumn(label: Text('Izvođač')),
        DataColumn(label: Text('Predložio')),
        DataColumn(label: Text('Stanje')),
        DataColumn(label: Text('Glasovi'), numeric: true),
        DataColumn(label: Text('Akcija')),
      ],
      rows: [
        for (final p in proposals)
          DataRow(
            selected: p.id == selectedId,
            onSelectChanged: (_) => onSelect(p.id),
            cells: [
              DataCell(Text(p.song.title)),
              DataCell(Text(p.song.artist)),
              DataCell(Text(p.proposedBy.value)),
              DataCell(ProposalStatusChip(p.status)),
              DataCell(Text('${tally[p.id] ?? 0}')),
              DataCell(
                canTransition(p.status, const Removed())
                    ? TextButton(
                        onPressed: () => onRemove(p.id),
                        child: const Text('Ukloni'),
                      )
                    : const Text('—'),
              ),
            ],
          ),
      ],
    );
  }
}

/// Bocni detalj izabranog predloga + akcija zatvaranja sobe.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.proposal,
    required this.votes,
    required this.onRemove,
    required this.room,
    required this.onCloseRoom,
  });

  final Proposal proposal;
  final int votes;
  final VoidCallback onRemove;
  final Room room;
  final VoidCallback onCloseRoom;

  @override
  Widget build(BuildContext context) {
    final removable = canTransition(proposal.status, const Removed());
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              proposal.song.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(proposal.song.artist),
            const SizedBox(height: 12),
            ProposalStatusChip(proposal.status),
            const SizedBox(height: 12),
            Text('Predložio: ${proposal.proposedBy.value}'),
            Text('Glasovi: $votes'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: removable ? onRemove : null,
              child: const Text('Ukloni predlog (Delete)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: room.status is RoomClosed ? null : onCloseRoom,
              child: const Text('Zatvori sobu'),
            ),
          ],
        ),
      ),
    );
  }
}
