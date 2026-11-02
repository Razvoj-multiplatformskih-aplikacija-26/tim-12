// Tok moderatora kroz pravi ruter: sobe → tabela → akcija → resize.
//
// Ovo je proba odbrane: lista soba, ulaz u sobu, uklanjanje uz dijalog,
// greška + "Pokusaj ponovo", tabela→lista bez gubitka izbora, tastatura.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radioroom_backoffice/data/fake_moderation_repository.dart';
import 'package:radioroom_backoffice/router.dart';

Future<void> _pumpApp(WidgetTester tester, FakeModerationRepository repo) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  return tester.pumpWidget(
    MaterialApp.router(routerConfig: createRouter(repository: repo)),
  );
}

void main() {
  testWidgets('lista soba pa ulaz u sobu daje tabelu', (tester) async {
    await _pumpApp(
      tester,
      FakeModerationRepository(delay: Duration.zero),
    );
    await tester.pumpAndSettle();
    expect(find.text('Petak u Studentskom'), findsOneWidget);
    expect(find.text('Subota kod Mike'), findsOneWidget);

    await tester.tap(find.text('Petak u Studentskom'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    // Izabrani (prvi) red vidi se i u tabeli i u bocnom panelu.
    expect(find.text('Fuego'), findsNWidgets(2));
  });

  testWidgets('greska, pa "Pokusaj ponovo" oporavlja', (tester) async {
    final repo = FakeModerationRepository(delay: Duration.zero)
      ..failNext = true;
    await _pumpApp(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Učitavanje nije uspelo.'), findsOneWidget);

    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pumpAndSettle();
    expect(find.text('Petak u Studentskom'), findsOneWidget);
  });

  testWidgets('Delete trazi potvrdu; potvrda uklanja predlog', (tester) async {
    await _pumpApp(
      tester,
      FakeModerationRepository(delay: Duration.zero),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petak u Studentskom'));
    await tester.pumpAndSettle();
    // r1: uklonjivi su p1, p2, p3 (glasanje) + p4 (predlozen) + p5 (pobednik).
    expect(find.widgetWithText(TextButton, 'Ukloni'), findsNWidgets(5));

    // Strelica dole: izbor sa prvog na drugi red; Delete otvara dijalog.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(find.text('Ukloni predlog?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ukloni'));
    await tester.pumpAndSettle();
    expect(find.text('Ukloni predlog?'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Ukloni'), findsNWidgets(4));
  });

  testWidgets('uzi prozor: lista umesto tabele, izbor ostaje', (tester) async {
    await _pumpApp(
      tester,
      FakeModerationRepository(delay: Duration.zero),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petak u Studentskom'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Fuego'), findsOneWidget);
    // Prvi red je i dalje izabran — resize nije izgubio izbor.
    final selected = find.byWidgetPredicate(
      (w) => w is ListTile && w.selected && w.title is Text,
    );
    expect(selected, findsOneWidget);
    expect(
      find.descendant(of: selected, matching: find.text('Fuego')),
      findsOneWidget,
    );
  });

  testWidgets('Backspace (Mac Delete) takodje otvara dijalog', (tester) async {
    await _pumpApp(
      tester,
      FakeModerationRepository(delay: Duration.zero),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petak u Studentskom'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.text('Ukloni predlog?'), findsOneWidget);

    // Otkazi: nista nije uklonjeno.
    await tester.tap(find.widgetWithText(TextButton, 'Otkaži'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Ukloni'), findsNWidgets(5));
  });

  testWidgets('lista soba: strelica bira, Enter otvara', (tester) async {
    await _pumpApp(
      tester,
      FakeModerationRepository(delay: Duration.zero),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // Druga soba (pauzirana): tabela sa njena 2 predloga.
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Mesečina'), findsNWidgets(2));
  });

  testWidgets('uzi prozor: tap otvara detalj sa akcijama', (tester) async {
    await _pumpApp(
      tester,
      FakeModerationRepository(delay: Duration.zero),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petak u Studentskom'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);

    await tester.tap(find.text('Fuego'));
    await tester.pumpAndSettle();
    // Donji sheet nosi iste akcije kao bocni panel.
    expect(find.text('Ukloni predlog (Delete)'), findsOneWidget);

    await tester.tap(find.text('Ukloni predlog (Delete)'));
    await tester.pumpAndSettle();
    expect(find.text('Ukloni predlog?'), findsOneWidget);
  });
}
