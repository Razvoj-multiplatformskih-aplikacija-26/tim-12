// Ekran liste soba: ulazna tacka moderatora (adresa `/sobe`).
//
// 4 stanja porta: ucitavanje / greska + "Pokusaj ponovo" / prazno / podaci.
// Tap otvara sobu (`/sobe/:roomId`); tastaturom: ↑/↓ bira, Enter otvara.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key, this.onSimulateError});

  /// Okidac greske sledeceg zahteva. Daje ga mesto sastavljanja aplikacije;
  /// bez njega stavka menija se ne prikazuje, pa zamena implementacije
  /// porta ne menja ovaj ekran.
  final VoidCallback? onSimulateError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobe'),
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
      body: BlocBuilder<ModerationBloc, ModerationState>(
        builder: (context, state) => switch (state) {
          ModerationInitial() || ModerationLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          ModerationError() => _ErrorView(
              onRetry: () =>
                  context.read<ModerationBloc>().add(const ModerationStarted()),
            ),
          ModerationLoaded(:final rooms) when rooms.isEmpty =>
            const Center(child: Text('Nema soba.')),
          ModerationLoaded(:final rooms) => _RoomsList(rooms: rooms),
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Učitavanje nije uspelo.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
}

class _RoomsList extends StatefulWidget {
  const _RoomsList({required this.rooms});

  final List<Room> rooms;

  @override
  State<_RoomsList> createState() => _RoomsListState();
}

/// Kretanje kroz sobe bez misa: ↑/↓ bira, Enter otvara (kao tap).
class _RoomsListState extends State<_RoomsList> {
  int _index = 0;

  void _open(Room room) {
    context.read<ModerationBloc>().add(ModerationRoomOpened(room.id));
    context.go('/sobe/${room.id.value}');
  }

  void _move(int delta) {
    if (widget.rooms.isEmpty) return;
    setState(() {
      _index = (_index + delta + widget.rooms.length) % widget.rooms.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.rooms.length) _index = 0;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _RoomsMoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _RoomsMoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _RoomsOpenIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _RoomsOpenIntent(),
      },
      child: Actions(
        actions: {
          _RoomsMoveIntent: CallbackAction<_RoomsMoveIntent>(
            onInvoke: (intent) => _move(intent.delta),
          ),
          _RoomsOpenIntent: CallbackAction<_RoomsOpenIntent>(
            onInvoke: (_) {
              _open(widget.rooms[_index]);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: ListView.builder(
            itemCount: widget.rooms.length,
            itemBuilder: (context, index) {
              final room = widget.rooms[index];
              return ListTile(
                selected: index == _index,
                selectedTileColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                title: Text(room.name),
                subtitle: Text(_statusLabel(room.status)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() => _index = index);
                  _open(room);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoomsMoveIntent extends Intent {
  const _RoomsMoveIntent(this.delta);

  final int delta;
}

class _RoomsOpenIntent extends Intent {
  const _RoomsOpenIntent();
}

String _statusLabel(RoomStatus status) => switch (status) {
      RoomOpen() => 'Otvorena',
      RoomPaused() => 'Pauzirana',
      RoomClosed() => 'Zatvorena',
    };
