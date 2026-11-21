// Prijava i cuvar ruta: login ekran, poruke na srpskom, odjava.
//
// Neprijavljen uvek zavrsava na `/login`; uspesna prijava vodi na sobe,
// pogresna lozinka ostaje na prijavi sa porukom, a odjava cisti token i
// vraca na prijavu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_mobile/data/fake_proposal_repository.dart';
import 'package:radioroom_mobile/main.dart';
import 'package:radioroom_mobile/router.dart';

import 'fake_auth_repository.dart';

const _delay = Duration(milliseconds: 10);

Future<(GoRouter, AuthBloc)> _start(
  WidgetTester tester,
  String location, {
  AuthBloc? auth,
}) async {
  final authBloc = auth ?? AuthBloc(
    repository: FakeAuthRepository(),
    tokenStore: FakeTokenStore(),
  );
  final router = createRouter(
    repository: FakeProposalRepository(delay: _delay),
    authBloc: authBloc,
  )..go(location);
  await tester.pumpWidget(RadioRoomApp(router: router, authBloc: authBloc));
  await tester.pump();
  await tester.pump(_delay);
  return (router, authBloc);
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _loginAs(
  WidgetTester tester,
  String username,
  String password,
) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Korisničko ime'),
    username,
  );
  await tester.enterText(find.widgetWithText(TextField, 'Lozinka'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
  await tester.pump();
  await tester.pump(_delay);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('neprijavljen na /sobe zavrsava na prijavi', (tester) async {
    final (router, _) = await _start(tester, '/sobe');
    expect(_location(router), '/login');
    expect(find.widgetWithText(TextField, 'Korisničko ime'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Lozinka'), findsOneWidget);
  });

  testWidgets('uspesna prijava vodi na sobe', (tester) async {
    final (router, _) = await _start(tester, '/login');
    await _loginAs(tester, 'ana', FakeAuthRepository.password);
    expect(_location(router), '/sobe');
    expect(find.text('Napravi sobu'), findsWidgets);
  });

  testWidgets('pogresna lozinka ostaje na prijavi sa porukom', (tester) async {
    final (router, _) = await _start(tester, '/login');
    await _loginAs(tester, 'ana', 'pogresna');
    expect(_location(router), '/login');
    expect(
      find.text('Neispravno korisničko ime ili lozinka. Probaj ponovo.'),
      findsOneWidget,
    );
  });

  testWidgets('prijavljen ne vidi login, vraca se na sobe', (tester) async {
    final auth = await authenticatedBloc();
    final (router, _) = await _start(tester, '/login', auth: auth);
    await tester.pumpAndSettle();
    expect(_location(router), '/sobe');
  });

  testWidgets('odjava cisti token i vraca na prijavu', (tester) async {
    final store = FakeTokenStore();
    final auth = await authenticatedBloc(store: store);
    expect(store.token, isNotNull);
    final (router, _) = await _start(tester, '/sobe', auth: auth);
    expect(_location(router), '/sobe');

    await tester.tap(find.byTooltip('Odjavi se'));
    await tester.pumpAndSettle();
    expect(store.token, isNull);
    expect(_location(router), '/login');
  });

  testWidgets('sacuvana sesija obnavlja prijavu bez kucanja', (tester) async {
    final repository = FakeAuthRepository();
    final store = FakeTokenStore();
    final first = AuthBloc(repository: repository, tokenStore: store);
    first.add(
      const LoginRequested(
        username: 'ana',
        password: FakeAuthRepository.password,
        app: AppTarget.mobile,
      ),
    );
    await first.stream.firstWhere((state) => state is Authenticated);
    await first.close();

    final restored = AuthBloc(repository: repository, tokenStore: store)
      ..add(const SessionRestored());
    final (router, _) = await _start(tester, '/sobe', auth: restored);
    await tester.pumpAndSettle();
    expect(_location(router), '/sobe');
    expect(find.text('Napravi sobu'), findsWidgets);
  });
}
