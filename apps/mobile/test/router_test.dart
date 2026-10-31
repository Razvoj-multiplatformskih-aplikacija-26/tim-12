// Navigacija: adresa po ekranu, preusmerenje i nepoznate adrese.
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
}
