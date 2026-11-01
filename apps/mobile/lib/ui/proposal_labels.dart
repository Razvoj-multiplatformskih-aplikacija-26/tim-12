// Sitni prikazi predloga zajednicki za listu i detalj: oznaka "Tvoj
// predlog", ko predlaze i vreme.
//
// U KT1 port ne vraca imena korisnika (samo `UserId`), pa se razlikuje
// samo "ti" i "drugi slusalac"; imena stizu sa prijavom u KT2.
import 'package:flutter/material.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Oznaka na predlogu tekuceg korisnika (ikonica + tekst, kao cip stanja).
class OwnProposalBadge extends StatelessWidget {
  const OwnProposalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(Icons.person, size: 16, color: scheme.onPrimaryContainer),
      label: const Text('Tvoj predlog'),
      backgroundColor: scheme.primaryContainer,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Ko predlaze, iz ugla tekuceg korisnika.
String proposerLabel(Proposal proposal, UserId currentUser) =>
    proposal.proposedBy == currentUser ? 'Ti' : 'Drugi slušalac';

/// Vreme u obliku HH:mm.
String clockTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';
