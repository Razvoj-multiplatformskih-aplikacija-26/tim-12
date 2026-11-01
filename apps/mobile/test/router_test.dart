// Navigacija: adresa po ekranu, preusmerenje i nepoznate adrese.
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

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('koren preusmerava na demo sobu', (tester) async {
    final router = await _start(tester, '/');
    expect(_location(router), '/soba/r1');
    expect(find.text('Petak u Studentskom'), findsOneWidget);
  });

  testWidgets('adresa sobe otvara listu te sobe', (tester) async {
    await _start(tester, '/soba/r1');
    expect(find.text('Fuego'), findsOneWidget);
  });

  testWidgets('nepoznata soba: ekran greske iz Bloc-a', (tester) async {
    await _start(tester, '/soba/r9');
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });

  testWidgets('nepoznata adresa: poruka i povratak na sobu', (tester) async {
    final router = await _start(tester, '/nesto');
    expect(find.text('Ova stranica ne postoji.'), findsOneWidget);

    await tester.tap(find.text('Nazad na sobu'));
    await tester.pump();
    await tester.pump(_delay);
    expect(_location(router), '/soba/r1');
    expect(find.text('Fuego'), findsOneWidget);
  });

  testWidgets('prekrsaj pravila: SnackBar sa porukom za celu sobu', (
    tester,
  ) async {
    await _start(tester, '/soba/r1');

    Future<void> vote() async {
      await tester.tap(find.widgetWithText(TextButton, 'Glasaj').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Glasaj'));
      await tester.pump();
      await tester.pump(_delay);
    }

    await vote();
    expect(find.byType(SnackBar), findsNothing);

    await vote();
    await tester.pump();
    expect(
      find.text('Tvoj glas u ovoj rundi je već zabeležen.'),
      findsOneWidget,
    );
  });

  group('detalj predloga', () {
    Finder infoRow(String label, String value) => find.ancestor(
      of: find.text(value),
      matching: find.widgetWithText(ListTile, label),
    );

    testWidgets('adresa otvara detalj tudjeg predloga', (tester) async {
      await _start(tester, '/soba/r1/predlog/p1');
      expect(find.text('Fuego'), findsOneWidget);
      expect(find.text('Eleni Foureira'), findsOneWidget);
      expect(find.text('U glasanju'), findsOneWidget);
      expect(infoRow('Predlaže', 'Drugi slušalac'), findsOneWidget);
      expect(infoRow('Glasovi', '2'), findsOneWidget);
      expect(find.text('Tvoj predlog'), findsNothing);
    });

    testWidgets('sopstveni predlog: "Ti" i oznaka', (tester) async {
      await _start(tester, '/soba/r1/predlog/p3');
      expect(infoRow('Predlaže', 'Ti'), findsOneWidget);
      expect(find.text('Tvoj predlog'), findsOneWidget);
    });

    testWidgets('pustena pesma: vreme pustanja, bez glasanja', (tester) async {
      await _start(tester, '/soba/r1/predlog/p8');
      expect(find.text('Puštena u'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Glasaj'), findsNothing);
    });

    testWidgets('nepostojeci predlog: poruka i povratak na sobu', (
      tester,
    ) async {
      final router = await _start(tester, '/soba/r1/predlog/nema');
      expect(find.text('Ovaj predlog ne postoji.'), findsOneWidget);

      await tester.tap(find.text('Nazad na sobu'));
      await tester.pumpAndSettle();
      expect(_location(router), '/soba/r1');
    });

    testWidgets('dodir na red liste otvara detalj, "nazad" vraca listu', (
      tester,
    ) async {
      final router = await _start(tester, '/soba/r1');
      await tester.tap(find.text('Mr. Brightside'));
      await tester.pumpAndSettle();
      expect(_location(router), '/soba/r1/predlog/p2');
      expect(find.text('The Killers'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_location(router), '/soba/r1');
    });

    testWidgets('glas sa detalja: potvrda, broj raste, drugi glas odbijen', (
      tester,
    ) async {
      await _start(tester, '/soba/r1/predlog/p2');
      expect(infoRow('Glasovi', '1'), findsOneWidget);

      Future<void> vote() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Glasaj'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Glasaj'),
          ),
        );
        // Dijalog se zatvara animacijom, a port odgovara posle kasnjenja.
        await tester.pumpAndSettle();
      }

      await vote();
      expect(infoRow('Glasovi', '2'), findsOneWidget);

      await vote();
      expect(
        find.text('Tvoj glas u ovoj rundi je već zabeležen.'),
        findsOneWidget,
      );
    });
  });
}
