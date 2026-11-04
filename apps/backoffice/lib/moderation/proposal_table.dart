// Tabela predloga (siri ekrani): red je izbor, kolona akcije uklanja.
import 'package:flutter/material.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

class ProposalTable extends StatelessWidget {
  const ProposalTable({
    super.key,
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
                    ? Tooltip(
                        message: 'Ukloni (Delete) — nepovratno',
                        child: TextButton(
                          onPressed: () => onRemove(p.id),
                          child: const Text('Ukloni'),
                        ),
                      )
                    : const Text('—'),
              ),
            ],
          ),
      ],
    );
  }
}
