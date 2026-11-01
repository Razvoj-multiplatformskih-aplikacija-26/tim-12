// Tab "Trenutno": sta sada svira — hero prikaz bez ijedne akcije glasanja.
//
// Veliki cover, izvodjac, album, traka runde i velika dugmad ka
// platformama (samo one koje pesma ima; KT1: samo trenutna pesma ima
// cover i prave linkove). Pobednik i lider ovde ne zive — to je Glasaj.
// Bez svog Scaffold-a: zivi u skoljkci sobe kao i ostali tabovi.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:url_launcher/url_launcher.dart';

import 'room_error_view.dart';

class NowTab extends StatelessWidget {
  const NowTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProposalListBloc, ProposalListState>(
      builder: (context, state) => switch (state) {
        ProposalsInitial() || ProposalsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
        ProposalsError() => const RoomErrorView(),
        ProposalsEmpty() => const Center(
            child: Text('Još nema predloga — budi prvi!'),
          ),
        ProposalsLoaded(:final snapshot) => _NowView(snapshot: snapshot),
      },
    );
  }
}

class _NowView extends StatelessWidget {
  const _NowView({required this.snapshot});

  final RoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = currentPlaying(
      proposals: snapshot.proposals,
      now: now,
    );
    final left = snapshot.round.endsAt.difference(now);
    final time = left.isNegative
        ? 'Runda je završena'
        : 'još ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    // KT1: linkove ima samo trenutna pesma.
    final links = current?.song.platformLinks;
    final song = current?.song;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Cover(url: song?.coverUrl),
        const SizedBox(height: 16),
        Text(
          current?.song.title ?? 'Još ništa ne svira',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          current == null
              ? 'Čeka se prvi pobednik.'
              : [
                  current.song.artist,
                  if (song?.album != null) song!.album!,
                ].join(' · '),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _RoundBar(time: time),
        if (links != null && links.isNotEmpty) ...[
          const SizedBox(height: 24),
          for (final entry in links.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlatformButton(
                platform: entry.key,
                url: entry.value,
              ),
            ),
        ],
      ],
    );
  }
}

/// Veliki cover; bez mreze ili adrese — neutralna ploca sa ikonom.
class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.music_note, size: 96),
    );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        url!,
        height: 280,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Traka runde: samo odbrojavanje (zadrzano po dogovoru).
class _RoundBar extends StatelessWidget {
  const _RoundBar({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text('Glasanje · $time'),
        ),
      );
}

/// Veliko dugme ka platformi; neuspeh otvaranja je SnackBar na srpskom.
class _PlatformButton extends StatelessWidget {
  const _PlatformButton({required this.platform, required this.url});

  final String platform;
  final String url;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.play_arrow),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Slušaj na $platform'),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Nije moguće otvoriti link.')),
          );
      }
    }
  }
}
