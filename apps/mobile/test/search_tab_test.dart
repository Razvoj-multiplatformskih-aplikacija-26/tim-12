// Pretraga tab: fokus sa FAB-a, rezultati, pravila, swipe izmedju tabova.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_mobile/data/fake_proposal_repository.dart';
import 'package:radioroom_mobile/main.dart';
import 'package:radioroom_mobile/router.dart';

import 'fake_auth_repository.dart';

const _delay = Duration(milliseconds: 10);

Future<GoRouter> _start(WidgetTester tester, String location) async {
  final auth = await authenticatedBloc();
  final router = createRouter(
    repository: FakeProposalRepository(delay: _delay),
    authBloc: auth,
  )..go(location);
  await tester.pumpWidget(RadioRoomApp(router: router, authBloc: auth));
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
    // Default je Glasaj (sredina): Sledeca kartica + lista sa rednim brojevima.
    expect(find.text('Sledeća · The White Stripes'), findsOneWidget);
    final fuego = find.ancestor(
      of: find.text('Fuego'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: fuego, matching: find.text('1')),
      findsOneWidget,
    );

    await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 800);
    // Ograniceni pumpovi, ne pumpAndSettle: traka runde na Trenutno tabu
    // tiktaka svake sekunde, pa se settle nikad ne bi desio.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Trenutno tab: hero cover + album + traka + dugmad (skroluj prvo:
    // dugmad su ispod folda i lenjo se montiraju).
    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
    expect(find.text('Queen · A Night at the Opera (1975)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Slušaj na Deezer'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    for (final label in [
      'Slušaj na Spotify',
      'Slušaj na YouTube Music',
      'Slušaj na YouTube',
      'Slušaj na Deezer',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.fling(find.byType(TabBarView), const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(TabBarView), const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    // Dva swipe-a desno: Trenutno → Glasaj → Pretraga.
    expect(find.widgetWithText(TextField, 'Pretraži pesme'), findsOneWidget);
  });

  testWidgets('odbrojavanje runde tiktaka svake sekunde', (tester) async {
    await _start(tester, '/soba/r1');
    await tester.fling(find.byType(TabBarView), const Offset(-300, 0), 800);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final before =
        tester.widget<Text>(find.textContaining('Glasanje ·')).data!;
    // Stvarno cekanje kroz runAsync: sat telefona (DateTime.now) ne prati
    // vestacki sat testa, pa virtuelni pump sam ne bi pomerio labelu.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump(const Duration(seconds: 1));
    final after =
        tester.widget<Text>(find.textContaining('Glasanje ·')).data!;
    expect(after, isNot(before));

    // Skloni tab sa ekrana da se tajmer otkaze pre kraja testa (inace
    // visi kao pending timer i rusi teardown).
    await tester.pumpWidget(Container());
  });
}
