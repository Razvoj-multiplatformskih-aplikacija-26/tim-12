// Pretraga tab: fokus sa FAB-a, rezultati, pravila, swipe izmedju tabova.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_mobile/data/demo_room.dart';
import 'package:radioroom_mobile/data/fake_proposal_repository.dart';
import 'package:radioroom_mobile/main.dart';
import 'package:radioroom_mobile/router.dart';

const _delay = Duration(milliseconds: 10);

Future<GoRouter> _start(WidgetTester tester, String location) async {
  final router = createRouter(
    repository: FakeProposalRepository(delay: _delay),
    currentUser: demoUser,
  )..go(location);
  await tester.pumpWidget(RadioRoomApp(router: router));
  await tester.pump();
  await tester.pump(_delay);
  return router;
}

bool _searchHasFocus(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

void main() {
  testWidgets('FAB prebacuje na Pretragu i otvara tastaturu', (tester) async {
    await _start(tester, '/soba/r1');
    expect(find.widgetWithText(TextField, 'Pretraži pesme'), findsNothing);

    await tester.tap(find.text('Predloži pesmu'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Pretraži pesme'), findsOneWidget);
    expect(_searchHasFocus(tester), isTrue);
  });

  testWidgets('kucanje filtrira postojece i katalog', (tester) async {
    await _start(tester, '/soba/r1');
    await tester.tap(find.text('Pretraga'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Pretraži pesme'),
      'fue',
    );
    await tester.pumpAndSettle();
    // Postojeci predlog sa glasanjem; katalog bez njega.
    expect(find.text('Fuego'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Predloži'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Pretraži pesme'),
      'queen',
    );
    await tester.pumpAndSettle();
    // Postojeci (Bohemian) + katalog bez duplikata (Under Pressure;
    // Bohemian iz kataloga otpada jer je vec u sobi).
    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
    expect(find.text('Under Pressure'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Predloži'), findsOneWidget);
  });

  testWidgets('kvota iz pretrage: SnackBar, ostaje se', (tester) async {
    // u1 vec ima 2 aktivna (p3, p5): prva dva prolaze, treci udara u limit.
    await _start(tester, '/soba/r1');
    await tester.tap(find.text('Pretraga'));
    await tester.pumpAndSettle();

    Future<void> propose(String q) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Pretraži pesme'),
        q,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Predloži').first);
      await tester.pumpAndSettle();
    }

    await propose('pressure');
    // Uspeh vodi nazad na Glasaj.
    expect(find.widgetWithText(TextField, 'Pretraži pesme'), findsNothing);

    await tester.tap(find.text('Pretraga'));
    await tester.pumpAndSettle();
    await propose('wonderwall');
    await tester.pumpAndSettle();
    // Pravilo odbija: poruka na srpskom, tab se ne menja.
    expect(find.textContaining('limit aktivnih'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Pretraži pesme'),
      findsOneWidget,
    );
  });

  testWidgets('swipe levo-desno menja tabove kao i bar', (tester) async {
    await _start(tester, '/soba/r1');
    // Default je Glasaj (sredina).
    expect(find.text('Sledeća · The White Stripes'), findsOneWidget);

    await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    // Trenutno tab: pobednik kartica i lider umesto liste glasanja.
    expect(find.text('Sledeća · pobednik runde'), findsOneWidget);
    expect(find.textContaining('Vodi Fuego'), findsOneWidget);

    await tester.fling(find.byType(TabBarView), const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(TabBarView), const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    // Dva swipe-a desno: Trenutno → Glasaj → Pretraga.
    expect(find.widgetWithText(TextField, 'Pretraži pesme'), findsOneWidget);
  });
}
