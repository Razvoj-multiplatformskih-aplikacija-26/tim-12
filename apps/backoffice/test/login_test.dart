// Prijava i cuvar ruta u backoffice-u: login ekran, odbijanje mobilnog
// naloga recima, odjava.
//
// Neprijavljen uvek zavrsava na `/login`; moderator posle prijave vidi
// sobe, slusalac se odbija porukom pravila, a odjava cisti token.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_backoffice/data/fake_moderation_repository.dart';
import 'package:radioroom_backoffice/main.dart';
import 'package:radioroom_backoffice/router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';

import 'fake_auth_repository.dart';

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
    repository: FakeModerationRepository(delay: Duration.zero),
    authBloc: authBloc,
  )..go(location);
  await tester.pumpWidget(BackofficeApp(router: router, authBloc: authBloc));
  await tester.pump();
  await tester.pumpAndSettle();
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
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('neprijavljen na /sobe zavrsava na prijavi', (tester) async {
    final (router, _) = await _start(tester, '/sobe');
    expect(_location(router), '/login');
    expect(find.widgetWithText(TextField, 'Korisničko ime'), findsOneWidget);
  });

  testWidgets('moderator posle prijave vidi sobe', (tester) async {
    final (router, _) = await _start(tester, '/login');
    await _loginAs(tester, 'moderator', FakeAuthRepository.password);
    expect(_location(router), '/sobe');
    expect(find.text('Petak u Studentskom'), findsOneWidget);
  });

  testWidgets('slusalac se odbija recima pravila', (tester) async {
    final (router, _) = await _start(tester, '/login');
    await _loginAs(tester, 'ana', FakeAuthRepository.password);
    expect(_location(router), '/login');
    expect(find.textContaining('Backoffice je za moderatore'), findsOneWidget);
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

  testWidgets('istek sesije usred rada vraca na prijavu', (tester) async {
    final auth = await authenticatedBloc();
    final (router, _) = await _start(tester, '/sobe', auth: auth);
    expect(_location(router), '/sobe');

    auth.add(const SessionExpired());
    await tester.pumpAndSettle();
    expect(_location(router), '/login');
  });
}
