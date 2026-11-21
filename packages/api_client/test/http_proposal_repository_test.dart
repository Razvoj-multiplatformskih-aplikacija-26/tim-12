// Testovi HTTP porta: svaka ruta (happy path + ServerRejected + mreza).
//
// `MockClient` vraca spremljene odgovore u wire formatu servera; zivi
// server za ove testove ne treba (rucna provera: curl u manifestu celine).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radioroom_api_client/radioroom_api_client.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

const _room = {
  'id': 'r1',
  'name': 'Petak',
  'hostId': 'h1',
  'status': 'open',
};
const _round = {
  'id': 'rd-r1',
  'roomId': 'r1',
  'startsAt': '2026-11-21T20:00:00.000Z',
  'endsAt': '2026-11-21T20:10:00.000Z',
};
const _proposal = {
  'id': 'p1',
  'roomId': 'r1',
  'song': {'title': 'Fuego', 'artist': 'Neki bend'},
  'proposedBy': 'u1',
  'proposedAt': '2026-11-21T20:01:00.000Z',
  'status': 'proposed',
};
const _vote = {
  'id': 'v1',
  'roundId': 'rd-r1',
  'proposalId': 'p1',
  'voterId': 'u1',
  'castAt': '2026-11-21T20:02:00.000Z',
};
const _snapshot = {
  'room': _room,
  'round': _round,
  'proposals': [_proposal],
  'votes': [_vote],
};

void main() {
  group('HttpProposalRepository', () {
    test('loadRooms cita listu soba', () async {
      final repository = _repository({'rooms': [_room]});
      final rooms = await repository.loadRooms();
      expect(rooms, hasLength(1));
      expect(rooms.single.name, 'Petak');
    });

    test('loadRooms prenosi ServerRejected sa kodom pravila', () async {
      final repository = _repository(
        {'code': 'backoffice_not_allowed', 'data': {'role': 'listener'}},
        status: 403,
      );
      await expectLater(
        repository.loadRooms(),
        throwsA(
          isA<ServerRejected>().having(
            (e) => e.error.code,
            'code',
            ErrorCodes.backofficeNotAllowed,
          ),
        ),
      );
    });

    test('loadRoom cita snimak i pamti sobu runde za glas', () async {
      Uri? seen;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seen = request.url;
          return _ok(_snapshot);
        }),
      );
      final repository = HttpProposalRepository(api);
      final snapshot = await repository.loadRoom(const RoomId('r1'));
      expect(seen.toString(), 'http://test/rooms/r1');
      expect(snapshot.room.name, 'Petak');
      expect(snapshot.proposals, hasLength(1));
      expect(snapshot.votes, hasLength(1));
    });

    test('loadRoom za nepostojecu sobu je ServerRejected (room_not_found)', () async {
      final repository = _repository({'code': 'room_not_found'}, status: 404);
      final error = await _rejection(
        () => repository.loadRoom(const RoomId('r9')),
      );
      expect(error.code, 'room_not_found');
    });

    test('createRoom salje samo naziv, host cita server iz tokena', () async {
      Map<String, Object?>? seen;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seen = jsonDecode(request.body) as Map<String, Object?>;
          return _ok(_room);
        }),
      );
      final room = await HttpProposalRepository(
        api,
      ).createRoom(name: 'Petak', hostId: const UserId('h1'));
      expect(seen, {'name': 'Petak'});
      expect(room.id, const RoomId('r1'));
    });

    test('propose salje pesmu i vraca predlog', () async {
      Map<String, Object?>? seen;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seen = jsonDecode(request.body) as Map<String, Object?>;
          return _ok(_proposal, status: 201);
        }),
      );
      final proposal = await HttpProposalRepository(api).propose(
        roomId: const RoomId('r1'),
        song: const Song(title: 'Fuego', artist: 'Neki bend'),
        proposedBy: const UserId('u1'),
      );
      expect(
        seen,
        {
          'song': {'title': 'Fuego', 'artist': 'Neki bend'},
        },
      );
      expect(proposal.id, const ProposalId('p1'));
    });

    test('propose prenosi odbijanje pravila (too_many_active_proposals)', () async {
      final repository = _repository({
        'code': 'too_many_active_proposals',
        'data': {'activeCount': 3, 'limit': 3},
      }, status: 422);
      final error = await _rejection(
        () => repository.propose(
          roomId: const RoomId('r1'),
          song: const Song(title: 'Fuego', artist: 'Neki bend'),
          proposedBy: const UserId('u1'),
        ),
      );
      expect(error.code, ErrorCodes.tooManyActiveProposals);
    });

    test('vote salje roundId i proposalId na putanju sobe', () async {
      Uri? seenUrl;
      Map<String, Object?>? seenBody;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seenUrl = request.url;
          if (request.body.isNotEmpty) {
            seenBody = jsonDecode(request.body) as Map<String, Object?>;
          }
          if (request.url.path == '/rooms/r1') return _ok(_snapshot);
          return _ok(_vote, status: 201);
        }),
      );
      final repository = HttpProposalRepository(api);
      await repository.loadRoom(const RoomId('r1'));
      final vote = await repository.vote(
        roundId: const RoundId('rd-r1'),
        proposalId: const ProposalId('p1'),
        voterId: const UserId('u1'),
      );
      expect(seenUrl.toString(), 'http://test/rooms/r1/votes');
      expect(seenBody, {'roundId': 'rd-r1', 'proposalId': 'p1'});
      expect(vote.id, const VoteId('v1'));
    });

    test('vote bez ucitane sobe je genericki Exception', () async {
      final repository = _repository(_vote, status: 201);
      await expectLater(
        repository.vote(
          roundId: const RoundId('rd-x'),
          proposalId: const ProposalId('p1'),
          voterId: const UserId('u1'),
        ),
        throwsA(isA<Exception>().having((e) => e, 'tip', isNot(isA<ServerRejected>()))),
      );
    });

    test('removeProposal udara .../remove i vraca predlog', () async {
      Uri? seenUrl;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seenUrl = request.url;
          return _ok({..._proposal, 'status': 'removed'});
        }),
      );
      final proposal = await HttpProposalRepository(api).removeProposal(
        roomId: const RoomId('r1'),
        proposalId: const ProposalId('p1'),
      );
      expect(seenUrl.toString(), 'http://test/rooms/r1/proposals/p1/remove');
      expect(proposal.status, const Removed());
    });

    test('closeRoom udara .../close i vraca zatvorenu sobu', () async {
      Uri? seenUrl;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seenUrl = request.url;
          return _ok({..._room, 'status': 'closed'});
        }),
      );
      final room = await HttpProposalRepository(
        api,
      ).closeRoom(roomId: const RoomId('r1'));
      expect(seenUrl.toString(), 'http://test/rooms/r1/close');
      expect(room.status, const RoomClosed());
    });

    test('mrezni kvar je genericki Exception, ne ServerRejected', () async {
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => throw http.ClientException('pad')),
      );
      await expectLater(
        HttpProposalRepository(api).loadRooms(),
        throwsA(isA<Exception>().having((e) => e, 'tip', isNot(isA<ServerRejected>()))),
      );
    });
  });
}

http.Response _ok(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status);

HttpProposalRepository _repository(Object body, {int status = 200}) =>
    HttpProposalRepository(
      ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response(jsonEncode(body), status)),
      ),
    );

Future<ApiError> _rejection(Future<void> Function() call) async {
  try {
    await call();
  } on ServerRejected catch (rejected) {
    return rejected.error;
  }
  return fail('ocekivano ServerRejected, proslo bez greske');
}
