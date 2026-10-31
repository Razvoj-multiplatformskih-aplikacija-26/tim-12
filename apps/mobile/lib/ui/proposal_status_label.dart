// Prikaz stanja predloga: oznaka na srpskom + ikonica.
//
// Stanje se nikad ne prikazuje samo bojom (odluka o UI stilu): cip uvek
// nosi i ikonicu i tekst. Exhaustive switch nad sealed tipom iz domena —
// novo stanje u domenu je greska kompajliranja ovde dok se ne doda prikaz.
import 'package:flutter/material.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Oznaka stanja na srpskom.
String statusLabel(ProposalStatus status) => switch (status) {
  Proposed() => 'Predložena',
  InVoting() => 'U glasanju',
  Winner() => 'Pobednik',
  Played() => 'Puštena',
  Rejected() => 'Odbijena',
  Removed() => 'Uklonjena',
};

/// Ikonica stanja.
IconData statusIcon(ProposalStatus status) => switch (status) {
  Proposed() => Icons.schedule,
  InVoting() => Icons.how_to_vote,
  Winner() => Icons.emoji_events,
  Played() => Icons.play_circle,
  Rejected() => Icons.cancel,
  Removed() => Icons.block,
};

/// Cip stanja: ikonica + oznaka.
class ProposalStatusChip extends StatelessWidget {
  const ProposalStatusChip(this.status, {super.key});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(statusIcon(status), size: 16),
    label: Text(statusLabel(status)),
    visualDensity: VisualDensity.compact,
  );
}
