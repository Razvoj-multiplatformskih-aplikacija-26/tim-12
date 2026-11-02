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
