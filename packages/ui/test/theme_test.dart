// Tema i cip stanja: odluke o UI stilu koje odbrana moze da proveri.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

void main() {
  test('svetla i tamna tema: Inter i paleta iz seed boje', () {
    final light = radioRoomTheme(Brightness.light);
    final dark = radioRoomTheme(Brightness.dark);
    expect(light.textTheme.bodyMedium!.fontFamily, contains('Inter'));
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(
      light.colorScheme.primary,
      ColorScheme.fromSeed(seedColor: brandSeed).primary,
    );
  });

  final allStates = <ProposalStatus>[
    const Proposed(),
    const InVoting(),
    const Winner(),
    Played(DateTime(2026)),
    const Rejected(),
    const Removed(),
  ];

  test('svako stanje ima svoju oznaku i boju', () {
    expect(allStates.map(statusLabel).toSet(), hasLength(6));
    expect(allStates.map(statusColor).toSet(), hasLength(6));
  });

  testWidgets('cip prikazuje i ikonicu i tekst (ne samo boju)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProposalStatusChip(InVoting()))),
    );
    expect(find.text('U glasanju'), findsOneWidget);
    expect(find.byIcon(Icons.how_to_vote), findsOneWidget);
  });
}
