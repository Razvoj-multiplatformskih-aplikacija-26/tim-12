// Skoljka sobe: tri taba — Pretraga | Glasaj | Trenutno.
//
// Swipe (`TabBarView`) i donji bar (`NavigationBar`) vozi isti
// `TabController`; podrazumevani je Glasaj (sredina). Tabovi su stanje
// ekrana sobe, ne adrese: pod-rute (`novi`, `predlog/:id`) ostaju ispod,
// pa "nazad" sa njih vraca na ovu skoljkU. Deljeni Bloc i SnackBar za
// `ruleError` zive na nivou sobe kao pre (obrazac iz stash MVP-a).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'now_tab.dart';
import 'proposal_list_screen.dart';
import 'search_tab.dart';

/// Redosled tabova; sredina je podrazumevana (glasanje je primarna radnja).
enum RoomTab { search, vote, now }

/// Podrazumevani rezim kad prekidac nije dat (sistemska tema, bez menija).
final _systemThemeMode = ValueNotifier(ThemeMode.system);

/// Labela suprotnog rezima: iz tamne u svetlu i obrnuto (sistemska se
/// tretira kao svetla).
String _themeLabel(ThemeMode mode) =>
    mode == ThemeMode.dark ? 'Svetla tema' : 'Tamna tema';

/// Ikonica suprotnog rezima.
IconData _themeIcon(ThemeMode mode) => mode == ThemeMode.dark
    ? Icons.light_mode_outlined
    : Icons.dark_mode_outlined;

class RoomShell extends StatefulWidget {
  const RoomShell({
    super.key,
    required this.roomId,
    required this.currentUser,
    this.onSimulateError,
    this.themeMode,
    this.onToggleTheme,
  });

  final RoomId roomId;
  final UserId currentUser;
  final VoidCallback? onSimulateError;

  /// Tekuci rezim teme (za labelu stavke) i prekidac na sledeci.
  /// Bez prekidaca stavke teme nema — meni tad ima samo gresku (ili ga
  /// uopste nema bez okidaca).
  final ValueListenable<ThemeMode>? themeMode;
  final VoidCallback? onToggleTheme;

  @override
  State<RoomShell> createState() => _RoomShellState();
}

class _RoomShellState extends State<RoomShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Fokus polja pretrage: FAB ga trazi kad prebaci na Pretraga tab.
  /// Polje se montira sa tabom, pa fokus stize nakon kraja animacije.
  final _searchFocus = FocusNode();

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
    _searchFocus.dispose();
    super.dispose();
  }

  void _goSearch() {
    _tabs.animateTo(RoomTab.search.index);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _tabs,
      builder: (context, _) => PopScope(
        // Sistemski "nazad" sa tabova vodi na home, ne iz aplikacije.
        // Pod-rute (`novi`, `predlog/:id`) su posebni ekrani iznad skoljke:
        // skoljka tamo nije u stablu pa se njihov "nazad" ne dira.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/sobe');
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Nazad na sobe',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/sobe'),
            ),
            title: BlocSelector<ProposalListBloc, ProposalListState, String>(
              selector: (state) => switch (state) {
                ProposalsLoaded(:final snapshot) ||
                ProposalsEmpty(:final snapshot) => snapshot.room.name,
                _ => 'RadioRoom',
              },
              builder: (_, title) => Text(title),
            ),
            actions: [
              // Meni postoji kad ima bar jedna stavka: tema uvek (ako je
              // dat prekidac), okidac greske samo uz dati okidac.
              if (widget.onToggleTheme != null ||
                  widget.onSimulateError != null)
                ValueListenableBuilder(
                  valueListenable:
                      widget.themeMode ?? _systemThemeMode,
                  builder: (_, mode, _) => PopupMenuButton<void>(
                    itemBuilder: (_) => [
                      if (widget.onToggleTheme != null)
                        PopupMenuItem(
                          onTap: widget.onToggleTheme,
                          child: ListTile(
                            leading: Icon(_themeIcon(mode)),
                            title: Text(_themeLabel(mode)),
                          ),
                        ),
                      if (widget.onSimulateError != null)
                        PopupMenuItem(
                          onTap: widget.onSimulateError,
                          child: const ListTile(
                            leading: Icon(Icons.error_outline),
                            title: Text('Simuliraj grešku'),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              SearchTab(
                focusNode: _searchFocus,
                onAccepted: () => _tabs.animateTo(RoomTab.vote.index),
                currentUser: widget.currentUser,
              ),
              ProposalListScreen(
                key: ValueKey(widget.roomId),
                roomId: widget.roomId,
                currentUser: widget.currentUser,
              ),
              const NowTab(),
            ],
          ),
        // FAB samo na Glasaj tabu i samo kad su podaci sobe tu.
        floatingActionButton: _tabs.index == RoomTab.vote.index
            ? BlocSelector<ProposalListBloc, ProposalListState, bool>(
                selector: (state) =>
                    state is ProposalsLoaded || state is ProposalsEmpty,
                builder: (context, hasData) => hasData
                    ? FloatingActionButton.extended(
                        onPressed: _goSearch,
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
      ),
    );
  }
}
