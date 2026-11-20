// Citanje soba nad pravim serverom i pocetnim podacima.
import 'dart:convert';

import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_server/radioroom_server.dart';
import 'package:test/test.dart';

import 'support/test_server.dart';

void main() {
  group('kodovi stanja', () {
    test('predlog: kod i nazad daju isto stanje', () {
      final playedAt = DateTime.utc(2026, 11, 20, 12);
      for (final status in <ProposalStatus>[
        const Proposed(),
        const InVoting(),
        const Winner(),
        Played(playedAt),
        const Rejected(),
        const Removed(),
      ]) {
        final back = proposalStatusFromCode(
          proposalStatusCode(status),
          playedAt,
        );
        expect(sameProposalStatus(back, status), isTrue, reason: '$status');
      }
    });

    test('soba: kod i nazad daju isto stanje', () {
      for (final status in <RoomStatus>[
        const RoomOpen(),
        const RoomPaused(),
        const RoomClosed(),
      ]) {
        expect(
          roomStatusFromCode(roomStatusCode(status)).runtimeType,
          status.runtimeType,
        );
      }
    });

    test('nepoznat kod je greska, ne tiho podrazumevano stanje', () {
      expect(() => proposalStatusFromCode('x', null), throwsFormatException);
      expect(() => roomStatusFromCode('x'), throwsFormatException);
    });
  });

  group('GET /rooms', () {
    test('trazi prijavu', () async {
      final server = await startTestServer();
      if (server == null) return;

      expect((await server.get('/rooms')).statusCode, 401);
      expect((await server.get('/rooms/r1')).statusCode, 401);
    });

    test('vraca sve sobe sa stanjem', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.get('/rooms', token: token);

      expect(response.statusCode, 200);
      final rooms = (jsonDecode(response.body) as Map)['rooms'] as List;
      expect(
        {for (final r in rooms) r['id']: r['status']},
        {'r1': 'open', 'r2': 'open', 'r3': 'paused', 'r4': 'closed'},
      );
      expect(rooms.firstWhere((r) => r['id'] == 'r1'), {
        'id': 'r1',
        'name': isNotEmpty,
        'hostId': 'h1',
        'status': 'open',
      });
    });
  });

  group('GET /rooms/:id', () {
    test('soba r1: tekuca runda, svi predlozi i glasovi runde', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.get('/rooms/r1', token: token);

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map;
      expect((body['room'] as Map)['id'], 'r1');

      final round = body['round'] as Map;
      expect(round['id'], 'rd2');
      final startsAt = DateTime.parse(round['startsAt'] as String);
      final endsAt = DateTime.parse(round['endsAt'] as String);
      expect(startsAt.isUtc && endsAt.isUtc, isTrue);
      expect(endsAt.isAfter(startsAt), isTrue);

      final proposals = body['proposals'] as List;
      expect(proposals, hasLength(12));
      expect(proposals.map((p) => p['status']).toSet(), {
        'proposed',
        'in_voting',
        'winner',
        'played',
        'rejected',
        'removed',
      });

      final played = proposals.firstWhere((p) => p['id'] == 'p8') as Map;
      expect(played['status'], 'played');
      expect(DateTime.parse(played['playedAt'] as String).isUtc, isTrue);
      expect(played['song'], containsPair('title', 'Bohemian Rhapsody'));
      expect(played['song'], containsPair('coverUrl', startsWith('https://')));
      // Samo pusteni nose trenutak pustanja.
      final voting = proposals.firstWhere((p) => p['id'] == 'p1') as Map;
      expect(voting.containsKey('playedAt'), isFalse);

      final votes = body['votes'] as List;
      expect(votes.map((v) => v['id']), ['v1', 'v2', 'v3']);
      expect(votes.every((v) => v['roundId'] == 'rd2'), isTrue);
    });

    test('prazna soba r2 ima rundu, a nema predloge ni glasove', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final body =
          jsonDecode((await server.get('/rooms/r2', token: token)).body) as Map;

      expect((body['round'] as Map)['id'], 'rd-r2');
      expect(body['proposals'], isEmpty);
      expect(body['votes'], isEmpty);
    });

    test('nepostojeca soba je 404 room_not_found', () async {
      final server = await startTestServer();
      if (server == null) return;
      final token = await server.login('ana');

      final response = await server.get('/rooms/nema', token: token);

      expect(response.statusCode, 404);
      expect(jsonDecode(response.body), {'code': 'room_not_found', 'data': {}});
    });
  });
}
