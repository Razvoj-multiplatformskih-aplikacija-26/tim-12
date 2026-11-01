// Forma novog predloga: pravila iz domena provereno pri unosu, poruke na
// srpskom, slanje i povratak na listu.
//
// Demo podaci: "Bohemian Rhapsody" (Queen) pustena pre 20 min, "Kisa pada"
// (Partibrejkers) pre 120 min; tekuci korisnik u1 ima 2 aktivna predloga.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mobile/data/demo_room.dart';
import 'package:radioroom_mobile/data/fake_proposal_repository.dart';
import 'package:radioroom_mobile/main.dart';
import 'package:radioroom_mobile/router.dart';
import 'package:radioroom_mobile/ui/new_proposal_screen.dart';

const _delay = Duration(milliseconds: 10);

late FakeProposalRepository _repo;

Future<GoRouter> _start(WidgetTester tester, String location) async {
  _repo = FakeProposalRepository(delay: _delay);
  final router = createRouter(repository: _repo, currentUser: demoUser)
    ..go(location);
  await tester.pumpWidget(RadioRoomApp(router: router));
  await tester.pump();
  await tester.pump(_delay);
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Finder _field(String label) => find.widgetWithText(TextField, label);

final _submit = find.widgetWithText(FilledButton, 'Predloži');

bool _canSubmit(WidgetTester tester) =>
    tester.widget<FilledButton>(_submit).onPressed != null;

Future<void> _type(WidgetTester tester, String title, String artist) async {
  await tester.enterText(_field('Naslov'), title);
  await tester.enterText(_field('Izvođač'), artist);
  await tester.pump();
}

final _recentlyPlayed = find.textContaining('je puštena u');

void main() {
  testWidgets('dugme na listi vodi na Pretragu, rucni unos na formu', (
    tester,
  ) async {
    final router = await _start(tester, '/soba/r1');
    await tester.tap(find.text('Predloži pesmu'));
    await tester.pumpAndSettle();
    expect(_location(router), '/soba/r1');
    expect(find.widgetWithText(TextField, 'Pretraži pesme'), findsOneWidget);

    await tester.tap(find.text('ili unesi pesmu ručno'));
    await tester.pumpAndSettle();
    expect(_location(router), '/soba/r1/novi');
    expect(_field('Naslov'), findsOneWidget);
  });

  testWidgets('prazna polja: dugme ugaseno, "Obavezno polje" posle unosa', (
    tester,
  ) async {
    await _start(tester, '/soba/r1/novi');
    expect(_canSubmit(tester), isFalse);
    expect(find.text('Obavezno polje'), findsNothing);

    await tester.enterText(_field('Naslov'), 'x');
    await tester.enterText(_field('Naslov'), '');
    await tester.pump();
    expect(find.text('Obavezno polje'), findsOneWidget);
    expect(_canSubmit(tester), isFalse);
  });

  testWidgets('nedavno pustena pesma: poruka pri unosu, dugme ugaseno', (
    tester,
  ) async {
    await _start(tester, '/soba/r1/novi');
    await _type(tester, 'Bohemian Rhapsody', 'Queen');
    expect(_recentlyPlayed, findsOneWidget);
    expect(_canSubmit(tester), isFalse);

    // Druga pesma: poruka nestaje, dugme se pali.
    await _type(tester, 'Under Pressure', 'Queen');
    expect(_recentlyPlayed, findsNothing);
    expect(_canSubmit(tester), isTrue);
  });

  testWidgets('ista pesma drugacije napisana je i dalje odbijena', (
    tester,
  ) async {
    await _start(tester, '/soba/r1/novi');
    await _type(tester, '  bohemian rhapsody ', 'QUEEN');
    expect(_recentlyPlayed, findsOneWidget);
    expect(_canSubmit(tester), isFalse);
  });

  testWidgets('pesma pustena pre vise od sat vremena je dozvoljena', (
    tester,
  ) async {
    await _start(tester, '/soba/r1/novi');
    await _type(tester, 'Kiša pada', 'Partibrejkers');
    expect(_recentlyPlayed, findsNothing);
    expect(_canSubmit(tester), isTrue);
  });

  testWidgets('slanje: povratak na listu, nov predlog sa oznakom i linkom', (
    tester,
  ) async {
    final router = await _start(tester, '/soba/r1/novi');
    await _type(tester, 'Under Pressure', 'Queen');
    await tester.enterText(_field('Link (opciono)'), 'https://youtu.be/a01');
    await tester.pump();
    await tester.tap(_submit);
    await tester.pump();
    // Ceka odgovor porta: polja zakljucana, na dugmetu spinner.
    expect(_location(router), '/soba/r1/novi');
    expect(_canSubmit(tester), isFalse);

    await tester.pumpAndSettle();
    expect(_location(router), '/soba/r1');
    // Nov predlog je predlozen: ceka u sklopljenoj sekciji na dnu liste —
    // prvo skroluj do nje (lenjo montiranje), pa rasklopi.
    await tester.scrollUntilVisible(
      find.textContaining('Na čekanju'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.textContaining('Na čekanju'));
    await tester.pumpAndSettle();
    // Red dovedi u sredinu da tap sigurno pogodi (delimicno vidljiv red
    // vara hit-test kroz donji bar).
    final tile = find.ancestor(
      of: find.text('Under Pressure'),
      matching: find.byType(ListTile),
    );
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: tile, matching: find.text('Tvoj predlog')),
      findsOneWidget,
    );

    await tester.tap(find.text('Under Pressure'));
    await tester.pumpAndSettle();
    expect(find.text('https://youtu.be/a01'), findsOneWidget);
  });

  testWidgets('treci aktivan predlog: forma posle toga prikazuje limit', (
    tester,
  ) async {
    final router = await _start(tester, '/soba/r1/novi');
    expect(find.textContaining('Dostignut je limit'), findsNothing);

    await _type(tester, 'Under Pressure', 'Queen');
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    // Kvota popunjena: povratak na formu pokazuje limit.
    router.go('/soba/r1/novi');
    await tester.pumpAndSettle();
    await _type(tester, 'Hey Jude', 'The Beatles');
    expect(find.textContaining('Dostignut je limit'), findsOneWidget);
    expect(_canSubmit(tester), isFalse);
  });

  testWidgets('tehnicka greska pri slanju: lista sa "Pokušaj ponovo"', (
    tester,
  ) async {
    final router = await _start(tester, '/soba/r1/novi');
    await _type(tester, 'Under Pressure', 'Queen');
    _repo.failNext = true;
    await tester.tap(_submit);
    await tester.pumpAndSettle();
    expect(_location(router), '/soba/r1');
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });

  testWidgets('Bloc odbije predlog pravilom: forma ostaje otvorena', (
    tester,
  ) async {
    // Kroz UI se ne moze izazvati (forma i Bloc proveravaju isti snimak),
    // pa forma dobija sat 2 h unapred: za nju je "Bohemian Rhapsody" van
    // roka, a Bloc (pravo vreme) je odbija. Bez rutera: pokusaj navigacije
    // bi pao, pa test dokazuje i da forma ne odlazi.
    final repo = FakeProposalRepository(delay: _delay);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ProposalListBloc(
            repository: repo,
            roomId: demoRoomId,
            currentUser: demoUser,
          )..add(const ProposalsRequested()),
          child: NewProposalScreen(
            currentUser: demoUser,
            clock: () => DateTime.now().add(const Duration(hours: 2)),
          ),
        ),
      ),
    );
    await tester.pump(_delay);

    await _type(tester, 'Bohemian Rhapsody', 'Queen');
    expect(_recentlyPlayed, findsNothing);
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    // I dalje na formi, unos sacuvan, dugme ponovo upaljeno.
    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
    expect(_canSubmit(tester), isTrue);
    // Bloc je zabelezio prekrsaj, a port nije pozvan: i dalje 12 predloga.
    final state =
        tester
                .element(find.byType(NewProposalScreen))
                .read<ProposalListBloc>()
                .state
            as ProposalsLoaded;
    expect(state.ruleError, isA<RecentlyPlayedSong>());
    expect(state.snapshot.proposals, hasLength(12));
  });
}
