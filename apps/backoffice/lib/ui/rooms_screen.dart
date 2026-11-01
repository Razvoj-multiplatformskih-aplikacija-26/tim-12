// Ekran liste soba: ulazna tacka moderatora (adresa `/sobe`).
//
// 4 stanja porta: ucitavanje / greska + "Pokusaj ponovo" / prazno / podaci.
// Tap otvara sobu (`/sobe/:roomId`); Enter na izabranoj radi isto (tastatura).
import 'package:flutter/material.dart';
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

class _RoomsList extends StatelessWidget {
  const _RoomsList({required this.rooms});

  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return ListTile(
          autofocus: index == 0,
          title: Text(room.name),
          subtitle: Text(_statusLabel(room.status)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.read<ModerationBloc>().add(ModerationRoomOpened(room.id));
            context.go('/sobe/${room.id.value}');
          },
        );
      },
    );
  }
}

String _statusLabel(RoomStatus status) => switch (status) {
      RoomOpen() => 'Otvorena',
      RoomPaused() => 'Pauzirana',
      RoomClosed() => 'Zatvorena',
    };
