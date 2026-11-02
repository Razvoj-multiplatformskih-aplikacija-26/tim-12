// Rasporedi moderacije: siri (tabela + bocni detalj) i uzak (lista).
//
// Odluka o sirini zivi u ekranu (`LayoutBuilder` + granica); ovde su samo
// dva rasporeda. Uzak tap ne navigira — obelezi red i otvori detalj u
// donjem sheet-u (adresa ostaje na sobi, izbor zivi u stanju ekrana).
// Tastatura i dalje samo pomera izbor, bez sheet-a.
import 'package:flutter/material.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'detail_panel.dart';
import 'proposal_table.dart';

/// Siri raspored: tabela levo, detalj u bocnom panelu desno.
class WideLayout extends StatelessWidget {
  const WideLayout({
    super.key,
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
            child: ProposalTable(
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
          child: DetailPanel(
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

/// Uzak raspored: lista umesto tabele; tap obelezi red i otvori detalj.
/// "Nazad" se vraca bez gubitka izbora (izbor zivi u stanju ekrana).
class NarrowLayout extends StatelessWidget {
  const NarrowLayout({
    super.key,
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
