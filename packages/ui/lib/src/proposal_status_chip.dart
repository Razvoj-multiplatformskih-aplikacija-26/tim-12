// Prikaz stanja predloga: oznaka na srpskom + ikonica + fiksna boja.
//
// Stanje se nikad ne prikazuje samo bojom (odluka o UI stilu): cip uvek
// nosi i ikonicu i tekst, a boja je dodatni znak. Boje su fiksne (iste u
// svetloj i tamnoj temi i u obe aplikacije). Exhaustive switch nad sealed
// tipom iz domena — novo stanje u domenu je greska kompajliranja ovde dok
// se ne doda prikaz.
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

/// Fiksna boja stanja.
Color statusColor(ProposalStatus status) => switch (status) {
  Proposed() => const Color(0xFF0E7490), // tirkizna — ceka
  InVoting() => const Color(0xFF5B3FD9), // boja brenda — aktivno
  Winner() => const Color(0xFFD97706), // ćilibar — pobednik
  Played() => const Color(0xFF16A34A), // zelena — zavrseno uspesno
  Rejected() => const Color(0xFFDC2626), // crvena — izgubila
  Removed() => const Color(0xFF6B7280), // siva — uklonjena
};

/// Cip stanja: obojena ikonica i ivica + oznaka.
class ProposalStatusChip extends StatelessWidget {
  const ProposalStatusChip(this.status, {super.key});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Chip(
      avatar: Icon(statusIcon(status), size: 16, color: color),
      label: Text(statusLabel(status)),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
