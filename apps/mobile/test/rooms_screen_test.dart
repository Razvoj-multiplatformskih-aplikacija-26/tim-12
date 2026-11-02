// Home tok: dva taba, pravljenje sobe, pridruzivanje, QR stub, greska.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mobile/data/fake_proposal_repository.dart';
import 'package:radioroom_mobile/main.dart';
import 'package:radioroom_mobile/router.dart';

const _delay = Duration(milliseconds: 10);

Future<GoRouter> _start(WidgetTester tester, String location) async {
  final router = createRouter(
    repository: FakeProposalRepository(delay: _delay),
    // currentUser je u KT1 i host novih soba.
    currentUser: const UserId('u1'),
  )..go(location);
  await tester.pumpWidget(RadioRoomApp(router: router));
  await tester.pump();
  await tester.pump(_delay);
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('home: dva taba, pridruzi se lista demo sobe', (tester) async {
    await _start(tester, '/sobe');
    await tester.pumpAndSettle();
    expect(find.text('Napravi sobu'), findsWidgets);
    expect(find.text('Pridruži se'), findsOneWidget);

    await tester.tap(find.text('Pridruži se'));
    await tester.pumpAndSettle();
    expect(find.text('Petak u Studentskom'), findsOneWidget);
    expect(find.text('Prazna soba'), findsOneWidget);
  });

  testWidgets('napravi sobu vodi unutra', (tester) async {
    final router = await _start(tester, '/sobe');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Naziv sobe'),
      'Moja soba',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Napravi sobu'));
    await tester.pumpAndSettle();

    expect(_location(router), '/soba/r3');
    expect(find.text('Moja soba'), findsOneWidget);
    expect(find.text('Još nema predloga — budi prvi!'), findsOneWidget);
  });

  testWidgets('prazan naziv: SnackBar, ostaje se', (tester) async {
    final router = await _start(tester, '/sobe');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Napravi sobu'));
    await tester.pumpAndSettle();

    expect(_location(router), '/sobe');
    expect(find.text('Naziv sobe ne sme biti prazan.'), findsOneWidget);
  });

  testWidgets('QR dugme: stub dijalog za KT2', (tester) async {
    await _start(tester, '/sobe');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pridruži se'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skeniraj QR kod'));
    await tester.pumpAndSettle();

    expect(find.text('QR kod'), findsOneWidget);
    expect(find.textContaining('stiže u KT2'), findsOneWidget);
    await tester.tap(find.text('U redu'));
    await tester.pumpAndSettle();
    expect(find.text('QR kod'), findsNothing);
  });

  testWidgets('greska, pa "Pokusaj ponovo" oporavlja', (tester) async {
    final repo = FakeProposalRepository(delay: _delay)..failNext = true;
    final router = createRouter(repository: repo, currentUser: const UserId('u1'))
      ..go('/sobe');
    await tester.pumpWidget(RadioRoomApp(router: router));
    await tester.pump();
    await tester.pump(_delay);
    await tester.pumpAndSettle();
    expect(find.text('Učitavanje nije uspelo.'), findsOneWidget);

    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pridruži se'));
    await tester.pumpAndSettle();
    expect(find.text('Petak u Studentskom'), findsOneWidget);
  });
}
