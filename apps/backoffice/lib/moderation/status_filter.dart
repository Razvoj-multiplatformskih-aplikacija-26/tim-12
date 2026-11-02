// Filter predloga po stanju (minimum za moderaciju: odvoji aktivne od
// zavrsenih). Vrednost zivi u stanju ekrana — menja samo prikaz, ne podatke.
import 'package:flutter/material.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

enum StatusFilter { all, active, finished }

extension StatusFilterX on StatusFilter {
  bool matches(Proposal p) => switch (this) {
        StatusFilter.all => true,
        StatusFilter.active => p.isActive,
        StatusFilter.finished => !p.isActive,
      };

  String get label => switch (this) {
        StatusFilter.all => 'Svi',
        StatusFilter.active => 'Aktivni',
        StatusFilter.finished => 'Završeni',
      };
}

/// Traka filtera i sortiranja iznad liste: menja samo prikaz, ne podatke.
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.filter,
    required this.sortByVotes,
    required this.onFilter,
    required this.onSort,
  });

  final StatusFilter filter;
  final bool sortByVotes;
  final ValueChanged<StatusFilter> onFilter;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<StatusFilter>(
            segments: [
              for (final f in StatusFilter.values)
                ButtonSegment(value: f, label: Text(f.label)),
            ],
            selected: {filter},
            onSelectionChanged: (set) => onFilter(set.single),
          ),
          TextButton.icon(
            onPressed: onSort,
            icon: Icon(sortByVotes ? Icons.arrow_downward : Icons.sort),
            label: const Text('Glasovi'),
          ),
        ],
      ),
    );
  }
}
