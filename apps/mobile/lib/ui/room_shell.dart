// Skoljka sobe: tri taba — Pretraga | Glasaj | Trenutno.
//
// Swipe (`TabBarView`) i donji bar (`NavigationBar`) vozi isti
// `TabController`; podrazumevani je Glasaj (sredina). Tabovi su stanje
// ekrana sobe, ne adrese: pod-rute (`novi`, `predlog/:id`) ostaju ispod,
// pa "nazad" sa njih vraca na ovu skoljkU. Deljeni Bloc i SnackBar za
// `ruleError` zive na nivou sobe kao pre (obrazac iz stash MVP-a).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import '../paths.dart';
import 'proposal_list_screen.dart';

/// Redosled tabova; sredina je podrazumevana (glasanje je primarna radnja).
enum RoomTab { search, vote, now }

class RoomShell extends StatefulWidget {
  const RoomShell({
    super.key,
    required this.roomId,
    required this.currentUser,
    this.onSimulateError,
  });

  final RoomId roomId;
  final UserId currentUser;
  final VoidCallback? onSimulateError;

  @override
  State<RoomShell> createState() => _RoomShellState();
}

class _RoomShellState extends State<RoomShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: RoomTab.values.length,
      initialIndex: RoomTab.vote.index,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _tabs,
      builder: (context, _) => Scaffold(
        body: TabBarView(
          controller: _tabs,
          children: [
            const _SearchPlaceholder(),
            ProposalListScreen(
              key: ValueKey(widget.roomId),
              roomId: widget.roomId,
              currentUser: widget.currentUser,
              onSimulateError: widget.onSimulateError,
            ),
            const _NowPlaceholder(),
          ],
        ),
        // FAB samo na Glasaj tabu i samo kad su podaci sobe tu
        // (kao pre: u gresci i ucitavanju ga nema).
        floatingActionButton: _tabs.index == RoomTab.vote.index
            ? BlocSelector<ProposalListBloc, ProposalListState, bool>(
                selector: (state) =>
                    state is ProposalsLoaded || state is ProposalsEmpty,
                builder: (context, hasData) => hasData
                    // Privremeno do koraka 4: vodi na formu; tada → Pretraga.
                    ? FloatingActionButton.extended(
                        onPressed: () =>
                            context.go(newProposalPath(widget.roomId)),
                        icon: const Icon(Icons.add),
                        label: const Text('Predloži pesmu'),
                      )
                    : const SizedBox.shrink(),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabs.index,
          onDestinationSelected: _tabs.animateTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search),
              label: 'Pretraga',
            ),
            NavigationDestination(
              icon: Icon(Icons.how_to_vote),
              label: 'Glasaj',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline),
              label: 'Trenutno',
            ),
          ],
        ),
      ),
    );
  }
}

/// Privremeno do koraka 4 (pravi sadrzaj pretrage).
class _SearchPlaceholder extends StatelessWidget {
  const _SearchPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Pretraga — uskoro'));
}

/// Privremeno do koraka 5 (sadrzaj iz stash MVP-a).
class _NowPlaceholder extends StatelessWidget {
  const _NowPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Trenutno — uskoro'));
}
