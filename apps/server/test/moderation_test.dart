// Akcije moderatora, povlacenje svog predloga i nova soba nad pravim
// serverom i pocetnim podacima.
//
// Pocetni podaci: p5 je anin (u1) predlog u stanju `proposed`, p1 je markov
// (u2) u glasanju, p7 markov pobednik, p6 sarin (u5) predlog, p8 pustena;
// r1 otvorena, r4 zatvorena; luka (h1) je host, moderator (m1).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/test_server.dart';

Map<String, Object?> _json(http.Response response) =>
    jsonDecode(response.body) as Map<String, Object?>;

Future<String> _status(TestServer server, String token, String id) async {
  final room = _json(await server.get('/rooms/r1', token: token));
  final proposal = (room['proposals']! as List).cast<Map>().firstWhere(
    (p) => p['id'] == id,
  );
  return proposal['status']! as String;
}

void main() {
  group('POST /rooms/:id/proposals/:pid/remove (samo moderator)', () {
    test('slusalac mimo aplikacije: 403 action_not_allowed', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r1/proposals/p6/remove',
        token: token,
      );

      expect(response.statusCode, 403);
      expect(_json(response), {
        'code': 'action_not_allowed',
        'data': {'action': 'removeProposal', 'role': 'listener'},
      });
      expect(await _status(server, token, 'p6'), 'proposed');
    });

    test('moderator uklanja tudj predlog', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('moderator', app: 'backoffice');

      final response = await server.post(
        '/rooms/r1/proposals/p6/remove',
        token: token,
      );

      expect(response.statusCode, 200, reason: response.body);
      expect(_json(response), containsPair('status', 'removed'));
      expect(await _status(server, token, 'p6'), 'removed');
    });

    test('pustena pesma se ne uklanja: 422 proposal_not_removable', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('moderator', app: 'backoffice');

      final response = await server.post(
        '/rooms/r1/proposals/p8/remove',
        token: token,
      );

      expect(response.statusCode, 422);
      expect(_json(response), {
        'code': 'proposal_not_removable',
        'data': {'proposalId': 'p8'},
      });
    });

    test('predlog van sobe: 404 proposal_not_found', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('moderator', app: 'backoffice');

      for (final path in [
        '/rooms/r1/proposals/nema/remove',
        '/rooms/r1/proposals/q1/remove',
      ]) {
        final response = await server.post(path, token: token);
        expect(response.statusCode, 404, reason: path);
        expect(_json(response)['code'], 'proposal_not_found');
      }
    });
  });

  group('POST /rooms/:id/close (samo moderator)', () {
    test('moderator zatvara sobu, posle nje nema predloga', () async {
      final server = await startTestServer();
      if (server == null) return;
      final moderator = await server.login('moderator', app: 'backoffice');
      final ana = await server.login('ana');

      final response = await server.post('/rooms/r1/close', token: moderator);

      expect(response.statusCode, 200, reason: response.body);
      expect(_json(response), containsPair('status', 'closed'));
      final propose = await server.post(
        '/rooms/r1/proposals',
        token: ana,
        body: {
          'song': {'title': 'Kasno', 'artist': 'Test'},
        },
      );
      expect(propose.statusCode, 422);
      expect(_json(propose)['code'], 'room_not_open');
    });

    test(
      'zatvorena soba se ne zatvara ponovo: 422 room_not_closable',
      () async {
        final server = await startTestServer();
        if (server == null) return;
        final token = await server.login('moderator', app: 'backoffice');

        final response = await server.post('/rooms/r4/close', token: token);

        expect(response.statusCode, 422);
        expect(_json(response), {'code': 'room_not_closable', 'data': {}});
      },
    );

    test('slusalac i host mimo aplikacije: 403', () async {
      final server = await startTestServer();
      if (server == null) return;

      for (final (user, role) in [('ana', 'listener'), ('luka', 'host')]) {
        final token = await server.login(user);
        final response = await server.post('/rooms/r1/close', token: token);
        expect(response.statusCode, 403, reason: user);
        expect(_json(response)['data'], {'action': 'closeRoom', 'role': role});
      }
    });
  });

  group('POST /rooms/:id/proposals/:pid/withdraw (samo svoj)', () {
    test('slusalac povlaci svoj predlog koji ceka ishod', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r1/proposals/p5/withdraw',
        token: token,
      );

      expect(response.statusCode, 200, reason: response.body);
      expect(_json(response), containsPair('status', 'removed'));
      expect(await _status(server, token, 'p5'), 'removed');
    });

    test('tudj predlog: 403 not_own_proposal', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.post(
        '/rooms/r1/proposals/p1/withdraw',
        token: token,
      );

      expect(response.statusCode, 403);
      expect(_json(response), {
        'code': 'not_own_proposal',
        'data': {'proposalId': 'p1'},
      });
      expect(await _status(server, token, 'p1'), 'in_voting');
    });

    test('pobednik se ne povlaci: 422 proposal_not_withdrawable', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('marko');

      final response = await server.post(
        '/rooms/r1/proposals/p7/withdraw',
        token: token,
      );

      expect(response.statusCode, 422);
      expect(_json(response), {
        'code': 'proposal_not_withdrawable',
        'data': {'proposalId': 'p7'},
      });
    });

    test('moderator ne povlaci tudje predloge (za to je uklanjanje)', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('moderator', app: 'backoffice');

      final response = await server.post(
        '/rooms/r1/proposals/p5/withdraw',
        token: token,
      );

      expect(response.statusCode, 403);
      expect(_json(response)['code'], 'action_not_allowed');
    });
  });

  group('POST /rooms (host)', () {
    test('host otvara sobu; soba odmah ima rundu', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('luka');

      final response = await server.post(
        '/rooms',
        token: token,
        body: {'name': '  Nova soba ', 'hostId': 'h2'},
      );

      expect(response.statusCode, 201, reason: response.body);
      final room = _json(response);
      expect(room, containsPair('name', 'Nova soba'));
      expect(room, containsPair('hostId', 'h1'));
      expect(room, containsPair('status', 'open'));

      final view = _json(
        await server.get('/rooms/${room['id']}', token: token),
      );
      expect(view['round'], isA<Map>());
      expect(view['proposals'], isEmpty);
    });

    test('slusalac ne otvara sobu: 403, prazan naziv: 422', () async {
      final server = await startTestServer();
      if (server == null) return;

      final ana = await server.post(
        '/rooms',
        token: await server.login('ana'),
        body: {'name': 'Moja'},
      );
      expect(ana.statusCode, 403);
      expect(_json(ana)['data'], {'action': 'createRoom', 'role': 'listener'});

      final empty = await server.post(
        '/rooms',
        token: await server.login('luka'),
        body: {'name': '   '},
      );
      expect(empty.statusCode, 422);
      expect(_json(empty), {'code': 'room_name_empty', 'data': {}});
    });
  });
}
