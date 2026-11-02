// Sitni prikazi predloga zajednicki za listu i detalj: oznaka "Tvoj
// predlog", ko predlaze i vreme.
//
// U KT1 port ne vraca imena korisnika (samo `UserId`), pa se razlikuje
// samo "ti" i "drugi slusalac"; imena stizu sa prijavom u KT2.
import 'package:flutter/material.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

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

/// Ikonica stanja za redove liste: bez teksta, sa bojom stanja.
/// Znacenje otkriva dugo zadrzavanje (tooltip); pun naziv zivi na detalju.
class ProposalStatusIcon extends StatelessWidget {
  const ProposalStatusIcon(this.status, {super.key});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: statusLabel(status),
        child: Icon(statusIcon(status), size: 18, color: statusColor(status)),
      );
}

/// Ikonica predloga tekuceg korisnika za redove liste: bez teksta.
/// Znacenje otkriva dugo zadrzavanje (tooltip); pun naziv zivi na detalju.
class OwnProposalIcon extends StatelessWidget {
  const OwnProposalIcon({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Tvoj predlog',
        child: Icon(
          Icons.person,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
}

/// Ko predlaze, iz ugla tekuceg korisnika.
String proposerLabel(Proposal proposal, UserId currentUser) =>
    proposal.proposedBy == currentUser ? 'Ti' : 'Drugi slušalac';

/// Vreme u obliku HH:mm.
String clockTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';
