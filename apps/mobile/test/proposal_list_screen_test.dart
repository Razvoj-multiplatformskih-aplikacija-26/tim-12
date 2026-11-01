// Ekran glavnog toka: sva 4 stanja (ucitavanje / greska / prazno / podaci).
//
// Ekran dobija SVOJU implementaciju porta iz testa, a ne lazni repozitorijum
// aplikacije — to je proba odbrane "zamena porta bez izmene ekrana": isti
// ekran radi nad bilo kojom implementacijom `ProposalRepository`.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mobile/data/demo_room.dart';
import 'package:radioroom_mobile/ui/room_shell.dart';

const _delay = Duration(milliseconds: 100);
final _now = DateTime(2026, 10, 31, 20);

/// Port iz testa: vraca zadati snimak (ili prazan), sa kasnjenjem i
/// jednokratnom greskom.
final class _TestRepository implements ProposalRepository {
  _TestRepository({required this.snapshot});

  RoomSnapshot snapshot;
  bool failNext = false;

  @override
  Future<RoomSnapshot> loadRoom(RoomId roomId) async {
    await Future<void>.delayed(_delay);
    if (failNext) {
      failNext = false;
      throw Exception('test');
    }
    return snapshot;
  }

  @override
  Future<Proposal> propose({
    required RoomId roomId,
    required Song song,
    required UserId proposedBy,
  }) => throw UnimplementedError();

  @override
  Future<Vote> vote({
    required RoundId roundId,
    required ProposalId proposalId,
    required UserId voterId,
  }) => throw UnimplementedError();

  @override
  Future<List<Room>> loadRooms() => throw UnimplementedError();

  @override
  Future<Proposal> removeProposal({
    required RoomId roomId,
    required ProposalId proposalId,
  }) => throw UnimplementedError();

  @override
  Future<Room> closeRoom({required RoomId roomId}) =>
      throw UnimplementedError();

  @override
  Future<Room> createRoom({required String name, required UserId hostId}) =>
      throw UnimplementedError();
}

RoomSnapshot _empty() {
  final full = demoRoom(_now);
  return RoomSnapshot(
    room: full.room,
    round: full.round,
    proposals: const [],
    votes: const [],
  );
}

Future<void> _pumpScreen(WidgetTester tester, _TestRepository repo) =>
    tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => ProposalListBloc(
            repository: repo,
            roomId: demoRoomId,
            currentUser: demoUser,
            clock: () => _now,
          )..add(const ProposalsRequested()),
          // Lista zivi u skoljkci sobe (Glasaj tab); FAB i bar stizu odatle.
          child: const RoomShell(
            roomId: demoRoomId,
            currentUser: demoUser,
          ),
        ),
      ),
    );

void main() {
  testWidgets('ucitavanje, pa podaci sa brojem glasova', (tester) async {
    await _pumpScreen(tester, _TestRepository(snapshot: demoRoom(_now)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(_delay);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Petak u Studentskom'), findsOneWidget);
    expect(find.text('Fuego'), findsOneWidget);
    // Fuego (p1) ima 2 glasa u demo podacima.
    final fuego = find.ancestor(
      of: find.text('Fuego'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: fuego, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('prazna soba: prazan prikaz i dugme za predlog', (
    tester,
  ) async {
    await _pumpScreen(tester, _TestRepository(snapshot: _empty()));
    await tester.pump(_delay);
    expect(find.text('Još nema predloga — budi prvi!'), findsOneWidget);
    expect(find.text('Predloži pesmu'), findsOneWidget);
  });

  testWidgets('greska, pa "Pokušaj ponovo" oporavlja', (tester) async {
    final repo = _TestRepository(snapshot: demoRoom(_now))..failNext = true;
    await _pumpScreen(tester, repo);
    await tester.pump(_delay);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
    expect(find.text('Predloži pesmu'), findsNothing);

    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(_delay);
    expect(find.text('Fuego'), findsOneWidget);
  });

  testWidgets('bez okidaca greske nema stavke menija', (tester) async {
    await _pumpScreen(tester, _TestRepository(snapshot: demoRoom(_now)));
    await tester.pump(_delay);
    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });

  testWidgets('oznaka "Tvoj predlog" samo na predlozima tekuceg korisnika', (
    tester,
  ) async {
    await _pumpScreen(tester, _TestRepository(snapshot: demoRoom(_now)));
    await tester.pump(_delay);
    // u1 u demo podacima: p3 (u glasanju) i p5 (predlozena).
    for (final title in ['Đurđevdan', 'Mesečina']) {
      final tile = find.ancestor(
        of: find.text(title),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: tile, matching: find.text('Tvoj predlog')),
        findsOneWidget,
      );
    }
    expect(find.text('Tvoj predlog'), findsNWidgets(2));
  });
}
