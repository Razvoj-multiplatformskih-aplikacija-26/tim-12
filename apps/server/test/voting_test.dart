// Predlaganje, glasanje i zatvaranje runde nad pravim serverom i pocetnim
// podacima, ukljucujuci istovremene pozive.
//
// Pocetni podaci (soba r1, runda rd2 istice za 8 min): ana (u1) ima 2
// aktivna predloga (p3 u glasanju, p5 predlozen) i jos nije glasala; p1 ima
// 2 glasa, p2 jedan; „Bohemian Rhapsody“ (p8) je pustena pre 20 min.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/test_server.dart';

Map<String, Object?> _json(http.Response response) =>
    jsonDecode(response.body) as Map<String, Object?>;

/// Koliko istovremenih poziva salju testovi trke.
const _parallel = 10;

Map<String, Object?> _song(String title) => {'title': title, 'artist': 'Test'};

void main() {
  group('POST /rooms/:id/proposals', () {
    test('predlog upisan, predlagac je iz prijave a ne iz tela', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r1/proposals',
        token: token,
        body: {
          'song': {
            'title': ' Take On Me ',
            'artist': 'a-ha',
            'durationMs': 225000,
          },
          'proposedBy': 'u2',
        },
      );

      expect(response.statusCode, 201, reason: response.body);
      final proposal = _json(response);
      expect(proposal['proposedBy'], 'u1');
      expect(proposal['status'], 'proposed');
      expect(proposal['song'], containsPair('title', 'Take On Me'));

      final room = _json(await server.get('/rooms/r1', token: token));
      expect(
        (room['proposals']! as List).map((p) => (p as Map)['id']),
        contains(proposal['id']),
      );
    });

    test('cetvrti aktivan predlog: 422 sa brojem i limitom', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final third = await server.post(
        '/rooms/r1/proposals',
        token: token,
        body: {'song': _song('Treca')},
      );
      final fourth = await server.post(
        '/rooms/r1/proposals',
        token: token,
        body: {'song': _song('Cetvrta')},
      );

      expect(third.statusCode, 201);
      expect(fourth.statusCode, 422);
      expect(_json(fourth), {
        'code': 'too_many_active_proposals',
        'data': {'activeCount': 3, 'limit': 3},
      });
    });

    test('pesma pustena pre 20 min: 422 recently_played_song', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r1/proposals',
        token: token,
        body: {
          'song': {'title': 'bohemian rhapsody', 'artist': 'QUEEN'},
        },
      );

      expect(response.statusCode, 422);
      final error = _json(response);
      expect(error['code'], 'recently_played_song');
      expect(error['data'], {
        'title': 'Bohemian Rhapsody',
        'artist': 'Queen',
        'playedAt': isA<String>(),
      });
    });

    test('zatvorena soba: 422 room_not_open sa stanjem', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r4/proposals',
        token: token,
        body: {'song': _song('Bilo sta')},
      );

      expect(response.statusCode, 422);
      expect(_json(response), {
        'code': 'room_not_open',
        'data': {'status': 'closed'},
      });
    });

    test('moderator ne predlaze: 403 action_not_allowed', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('moderator');

      final response = await server.post(
        '/rooms/r1/proposals',
        token: token,
        body: {'song': _song('Bilo sta')},
      );

      expect(response.statusCode, 403);
      expect(_json(response), {
        'code': 'action_not_allowed',
        'data': {'action': 'propose', 'role': 'moderator'},
      });
    });

    test('los oblik tela: 400, nepostojeca soba: 404', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      for (final body in [
        <String, Object?>{},
        {'song': 'Fuego'},
        {
          'song': {'title': '  ', 'artist': 'X'},
        },
        {
          'song': {'title': 'X', 'artist': 'Y', 'durationMs': -1},
        },
      ]) {
        final response = await server.post(
          '/rooms/r1/proposals',
          token: token,
          body: body,
        );
        expect(response.statusCode, 400, reason: '$body');
      }
      final missing = await server.post(
        '/rooms/nema/proposals',
        token: token,
        body: {'song': _song('X')},
      );
      expect(missing.statusCode, 404);
    });
  });

  group('POST /rooms/:id/votes', () {
    Map<String, Object?> vote(String proposal, {String round = 'rd2'}) => {
      'roundId': round,
      'proposalId': proposal,
    };

    test('glas upisan, glasac je iz prijave', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r1/votes',
        token: token,
        body: {...vote('p2'), 'voterId': 'u2'},
      );

      expect(response.statusCode, 201, reason: response.body);
      expect(_json(response), containsPair('voterId', 'u1'));
      expect(_json(response), containsPair('roundId', 'rd2'));
    });

    test('drugi glas u rundi: 409 already_voted_in_round', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      await server.post('/rooms/r1/votes', token: token, body: vote('p1'));
      final second = await server.post(
        '/rooms/r1/votes',
        token: token,
        body: vote('p2'),
      );

      expect(second.statusCode, 409);
      expect(_json(second), {
        'code': 'already_voted_in_round',
        'data': {'roundId': 'rd2'},
      });
    });

    test(
      'predlog van glasanja ili van sobe: 422 invalid_vote_target',
      () async {
        final server = await startTestServer();
        if (server == null) return;
        final token = await server.login('ana');

        for (final proposal in ['p5', 'q2', 'nema']) {
          final response = await server.post(
            '/rooms/r1/votes',
            token: token,
            body: vote(proposal),
          );
          expect(response.statusCode, 422, reason: proposal);
          expect(_json(response), {
            'code': 'invalid_vote_target',
            'data': {'proposalId': proposal},
          });
        }
      },
    );

    test('pauzirana soba: 422 room_not_open', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r3/votes',
        token: token,
        body: vote('q2', round: 'rd-r3'),
      );

      expect(response.statusCode, 422);
      expect(_json(response), {
        'code': 'room_not_open',
        'data': {'status': 'paused'},
      });
    });

    test('moderator ne glasa: 403 action_not_allowed', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('moderator');

      final response = await server.post(
        '/rooms/r1/votes',
        token: token,
        body: vote('p1'),
      );

      expect(response.statusCode, 403);
      expect((_json(response)['data']! as Map)['action'], 'vote');
    });
  });

  group('istovremeni pozivi', () {
    test(
      'deset istovremenih glasova istog slusaoca: prolazi tacno jedan',
      () async {
        final server = await startTestServer();
        if (server == null) return;
        final token = await server.login('ana');

        final responses = await Future.wait([
          for (var i = 0; i < _parallel; i++)
            server.post(
              '/rooms/r1/votes',
              token: token,
              body: {'roundId': 'rd2', 'proposalId': 'p${1 + i % 4}'},
            ),
        ]);

        final codes = responses.map((r) => r.statusCode);
        expect(codes.where((c) => c == 201), hasLength(1));
        expect(codes.where((c) => c == 409), hasLength(_parallel - 1));
        final room = _json(await server.get('/rooms/r1', token: token));
        final anaVotes = (room['votes']! as List).where(
          (v) => (v as Map)['voterId'] == 'u1',
        );
        expect(anaVotes, hasLength(1));
      },
    );

    test(
      'deset istovremenih predloga uz 2 aktivna: prolazi tacno jedan',
      () async {
        final server = await startTestServer();
        if (server == null) return;
        final token = await server.login('ana');

        final responses = await Future.wait([
          for (var i = 0; i < _parallel; i++)
            server.post(
              '/rooms/r1/proposals',
              token: token,
              body: {'song': _song('Istovremena $i')},
            ),
        ]);

        final codes = responses.map((r) => r.statusCode);
        expect(codes.where((c) => c == 201), hasLength(1));
        expect(codes.where((c) => c == 422), hasLength(_parallel - 1));
        final room = _json(await server.get('/rooms/r1', token: token));
        final active = (room['proposals']! as List).where(
          (p) =>
              (p as Map)['proposedBy'] == 'u1' &&
              {'proposed', 'in_voting'}.contains(p['status']),
        );
        expect(active, hasLength(3));
      },
    );
  });

  group('zatvaranje runde', () {
    test('posle isteka: pobednik, odbijeni, preneti i nova runda', () async {
      var now = DateTime.now();
      final server = await startTestServer(clock: () => now);
      if (server == null) return;
      final token = await server.login('ana');

      now = now.add(const Duration(minutes: 11));
      final room = _json(await server.get('/rooms/r1', token: token));

      final round = room['round']! as Map;
      expect(round['id'], isNot('rd2'));
      expect(
        DateTime.parse(
          round['endsAt']! as String,
        ).difference(DateTime.parse(round['startsAt']! as String)),
        const Duration(minutes: 10),
      );
      expect(room['votes'], isEmpty);

      final proposals = (room['proposals']! as List).cast<Map>();
      String status(String id) =>
          proposals.firstWhere((p) => p['id'] == id)['status']! as String;
      expect(status('p1'), 'winner'); // 2 glasa
      expect(status('p2'), 'rejected'); // 1 glas — vraca se kao nov predlog
      expect(status('p3'), 'rejected'); // 0 glasova — ispada
      expect(status('p4'), 'rejected');
      expect(status('p5'), 'in_voting'); // cekao je — ulazi u novu rundu
      expect(status('p6'), 'in_voting');
      expect(status('p7'), 'winner'); // raniji pobednik i dalje ceka pustanje

      final carried = proposals.where(
        (p) =>
            (p['song']! as Map)['title'] == 'Mr. Brightside' && p['id'] != 'p2',
      );
      expect(carried, hasLength(1));
      expect(carried.single['status'], 'in_voting');
      expect(carried.single['proposedBy'], 'u3');
    });

    test(
      'deset istovremenih citanja posle isteka: runda se zatvara jednom',
      () async {
        var now = DateTime.now();
        final server = await startTestServer(clock: () => now);
        if (server == null) return;
        final token = await server.login('ana');

        now = now.add(const Duration(minutes: 11));
        final rooms = (await Future.wait([
          for (var i = 0; i < _parallel; i++)
            server.get('/rooms/r1', token: token),
        ])).map(_json).toList();

        final roundIds = rooms.map((r) => (r['round']! as Map)['id']).toSet();
        expect(roundIds, hasLength(1));
        final carried = (rooms.last['proposals']! as List).where(
          (p) => ((p as Map)['song']! as Map)['title'] == 'Mr. Brightside',
        );
        expect(carried, hasLength(2)); // p2 (odbijen) + jedna kopija
      },
    );

    test('zakasneli glas za zatvorenu rundu: 422 round_closed', () async {
      var now = DateTime.now();
      final server = await startTestServer(clock: () => now);
      if (server == null) return;
      final token = await server.login('ana');

      now = now.add(const Duration(minutes: 11));
      final response = await server.post(
        '/rooms/r1/votes',
        token: token,
        body: {'roundId': 'rd2', 'proposalId': 'p1'},
      );

      expect(response.statusCode, 422);
      expect(_json(response), {
        'code': 'round_closed',
        'data': {'roundId': 'rd2'},
      });
    });

    test('runda bez glasova nikoga ne odbija', () async {
      var now = DateTime.now();
      final server = await startTestServer(clock: () => now);
      if (server == null) return;
      final token = await server.login('ana');
      final created = _json(
        await server.post(
          '/rooms/r2/proposals',
          token: token,
          body: {'song': _song('Prva u praznoj')},
        ),
      );

      // Prvi istek: predlog ulazi u glasanje. Drugi: niko nije glasao.
      now = now.add(const Duration(minutes: 11));
      await server.get('/rooms/r2', token: token);
      now = now.add(const Duration(minutes: 11));
      final room = _json(await server.get('/rooms/r2', token: token));

      final proposals = (room['proposals']! as List).cast<Map>();
      expect(proposals, hasLength(1));
      expect(proposals.single['id'], created['id']);
      expect(proposals.single['status'], 'in_voting');
    });

    test('pauzirana soba ne zatvara rundu', () async {
      var now = DateTime.now();
      final server = await startTestServer(clock: () => now);
      if (server == null) return;
      final token = await server.login('ana');

      now = now.add(const Duration(minutes: 11));
      final room = _json(await server.get('/rooms/r3', token: token));

      expect((room['round']! as Map)['id'], 'rd-r3');
    });
  });
}
