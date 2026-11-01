// Pocetna stranica: dva taba — Napravi sobu | Pridruzi se.
//
// U KT1 nema prijave ni servera: napravljena soba pravi se lokalno kroz
// port (isti mehanizam kao ostale akcije), a pridruzivanje je izbor sa
// liste postojecih soba. QR skeniranje i kod stizu tek u KT2 (`joinCode`);
// dugme i polje postoje kao vidljiv stub sa porukom, nista ne laze.
// Ekran samo salje dogadjaje i crta stanje `RoomsBloc`-a.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  int _knownCount = -1;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoomsBloc, RoomsState>(
      listenWhen: (_, state) =>
          state is RoomsLoaded && state.rooms.length > _knownCount,
      listener: (context, state) {
        final rooms = (state as RoomsLoaded).rooms;
        if (_knownCount >= 0 && rooms.isNotEmpty) {
          context.go('/soba/${rooms.last.id.value}');
        }
        _knownCount = rooms.length;
      },
      child: BlocListener<RoomsBloc, RoomsState>(
        listenWhen: (_, state) =>
            state is RoomsLoaded && state.ruleError != null,
        listener: (context, state) {
          final error = (state as RoomsLoaded).ruleError!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(ruleMessage(error))));
        },
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('RadioRoom'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Napravi sobu'),
                  Tab(text: 'Pridruži se'),
                ],
              ),
            ),
            body: BlocBuilder<RoomsBloc, RoomsState>(
              builder: (context, state) => switch (state) {
                RoomsInitial() || RoomsLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                RoomsError() => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Učitavanje nije uspelo.'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context
                              .read<RoomsBloc>()
                              .add(const RoomsRequested()),
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                RoomsLoaded(:final rooms) => TabBarView(
                    children: [
                      _CreateTab(rooms: rooms),
                      _JoinTab(rooms: rooms),
                    ],
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab "Napravi sobu": naziv + dugme. Prazan naziv odbija domen
/// (`RoomNameEmpty` → SnackBar), port se ne zove.
class _CreateTab extends StatefulWidget {
  const _CreateTab({required this.rooms});

  final List<Room> rooms;

  @override
  State<_CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<_CreateTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Napravi sobu za svoju ekipu.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Naziv sobe',
              hintText: 'npr. Petak kod Mike',
            ),
            onSubmitted: (_) => _submit(context),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _submit(context),
            child: const Text('Napravi sobu'),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    context.read<RoomsBloc>().add(RoomCreated(_controller.text));
  }
}

/// Tab "Pridruzi se": lista postojecih soba + QR/kod (stub za KT2).
class _JoinTab extends StatelessWidget {
  const _JoinTab({required this.rooms});

  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(
        child: Text('Još nema soba — napravi prvu!'),
      );
    }
    return ListView(
      children: [
        for (final room in rooms)
          ListTile(
            title: Text(room.name),
            subtitle: Text(_statusLabel(room.status)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/soba/${room.id.value}'),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => _qrStub(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Skeniraj QR kod'),
          ),
        ),
      ],
    );
  }

  Future<void> _qrStub(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QR kod'),
          content: const Text(
            'Skeniranje QR koda stiže u KT2, sa prijavom i serverom. '
            'Za sad izaberi sobu sa liste.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('U redu'),
            ),
          ],
        ),
      );
}

String _statusLabel(RoomStatus status) => switch (status) {
      RoomOpen() => 'Otvorena',
      RoomPaused() => 'Pauzirana',
      RoomClosed() => 'Zatvorena',
    };
