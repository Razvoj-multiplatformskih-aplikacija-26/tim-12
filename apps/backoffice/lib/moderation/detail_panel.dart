// Bocni detalj izabranog predloga + akcija zatvaranja sobe.
//
// Isti panel zivi na dva mesta: kao bocni stub u sirokom rasporedu i kao
// sadrzaj donjeg sheet-a u uskom — zato je izdvojen, da se akcije ne
// dupliraju.
import 'package:flutter/material.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

class DetailPanel extends StatelessWidget {
  const DetailPanel({
    super.key,
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
    final roomClosed = room.status is RoomClosed;
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
            Text('Predložen: ${_formatDateTime(proposal.proposedAt)}'),
            Text('Glasovi: $votes'),
            if (proposal.song.externalLink case final link?)
              Text('Link: $link'),
            const SizedBox(height: 16),
            Tooltip(
              message: 'Ukloni predlog (Delete) — nepovratno',
              child: FilledButton(
                onPressed: removable ? onRemove : null,
                child: const Text('Ukloni predlog (Delete)'),
              ),
            ),
            if (!removable)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Predlog je u završnom stanju — uklanjanje nije moguće.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Zatvori sobu — nepovratno',
              child: OutlinedButton(
                onPressed: roomClosed ? null : onCloseRoom,
                child: const Text('Zatvori sobu'),
              ),
            ),
            if (roomClosed)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Soba je zatvorena.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Datum i vreme bez `intl` zavisnosti: 31.10.2026 20:05.
String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
