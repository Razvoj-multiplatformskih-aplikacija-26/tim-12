// DTO: oblik tela i odgovora uskladjen sa serverom.
//
// Prijava prati login-odgovor iz `apps/server` (`{token, expiresAt, user:
// {id, displayName, role}}`); predlog, glas, soba, runda i snimak sobe prate
// odgovore ruta soba. Prevod u domen testira `packages/mapping`.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:test/test.dart';

void main() {
  group('prijava', () {
    test('LoginRequest salje username, password i app', () {
      const request = LoginRequest(
        username: 'ana',
        password: 'demo1234',
        app: AppTarget.backoffice,
      );

      expect(request.toJson(), {
        'username': 'ana',
        'password': 'demo1234',
        'app': 'backoffice',
      });
    });

    test('LoginRequest podrazumeva mobilnu aplikaciju', () {
      expect(
        const LoginRequest(username: 'a', password: 'b').toJson()['app'],
        'mobile',
      );
      expect(
        LoginRequest.fromJson({'username': 'a', 'password': 'b'}).app,
        AppTarget.mobile,
      );
    });

    test('LoginRequest baca za nepoznatu aplikaciju', () {
      expect(
        () => LoginRequest.fromJson({
          'username': 'a',
          'password': 'b',
          'app': 'televizor',
        }),
        throwsFormatException,
      );
    });

    test('LoginResponse krug json<->dto', () {
      final json = {
        'token': 't-1',
        'expiresAt': '2026-11-20T12:00:00.000Z',
        'user': {'id': 'u1', 'displayName': 'Ana', 'role': 'listener'},
      };

      final response = LoginResponse.fromJson(json);

      expect(response.token, 't-1');
      expect(response.user.role, RoleCodes.listener);
      expect(response.user.blocked, isFalse);
      expect(response.toJson(), json);
    });

    test('UserDto baca za nepoznatu ulogu', () {
      expect(
        () => UserDto.fromJson({
          'id': 'u1',
          'displayName': 'A',
          'role': 'superadmin',
        }),
        throwsFormatException,
      );
    });
  });

  group('pesme, predlozi i glasovi', () {
    test('SongDto salje samo polja koja postoje', () {
      expect(const SongDto(title: 'Fuego', artist: 'Severina').toJson(), {
        'title': 'Fuego',
        'artist': 'Severina',
      });
      final full = SongDto.fromJson({
        'title': 'Fuego',
        'artist': 'Severina',
        'album': 'Dobro jutro',
        'durationMs': 180000,
        'externalLink': 'https://example.com/fuego',
        'coverUrl': null,
      });
      expect(full.album, 'Dobro jutro');
      expect(full.durationMs, 180000);
      expect(full.toJson().keys, isNot(contains('coverUrl')));
    });

    test('ProposalDto krug json<->dto, playedAt samo uz played', () {
      final json = {
        'id': 'p1',
        'roomId': 'r1',
        'song': {'title': 'Fuego', 'artist': 'Severina'},
        'proposedBy': 'u1',
        'proposedAt': '2026-11-20T10:00:00.000Z',
        'status': 'played',
        'playedAt': '2026-11-20T11:40:00.000Z',
      };

      final dto = ProposalDto.fromJson(json);

      expect(dto.status, ProposalStatusCodes.played);
      expect(dto.playedAt, DateTime.utc(2026, 11, 20, 11, 40));
      expect(dto.toJson(), json);
    });

    test('ProposalDto baca za nepoznato stanje i played bez vremena', () {
      final base = {
        'id': 'p1',
        'roomId': 'r1',
        'song': {'title': 'T', 'artist': 'A'},
        'proposedBy': 'u1',
        'proposedAt': '2026-11-20T10:00:00.000Z',
      };
      expect(
        () => ProposalDto.fromJson({...base, 'status': 'leprsa_u_vazduhu'}),
        throwsFormatException,
      );
      expect(
        () => ProposalDto.fromJson({...base, 'status': 'played'}),
        throwsFormatException,
      );
    });

    test('CreateProposalRequest ne salje identitet predlagaca', () {
      final body = const CreateProposalRequest(
        song: SongDto(title: 'Fuego', artist: 'Severina'),
      ).toJson();

      expect(body, {
        'song': {'title': 'Fuego', 'artist': 'Severina'},
      });
    });

    test('VoteDto krug json<->dto', () {
      final json = {
        'id': 'v1',
        'roundId': 'rd1',
        'proposalId': 'p1',
        'voterId': 'u1',
        'castAt': '2026-11-20T10:05:00.000Z',
      };
      expect(VoteDto.fromJson(json).toJson(), json);
    });

    test('CastVoteRequest salje rundu i predlog, trazi oba', () {
      expect(const CastVoteRequest(roundId: 'rd1', proposalId: 'p1').toJson(), {
        'roundId': 'rd1',
        'proposalId': 'p1',
      });
      expect(
        () => CastVoteRequest.fromJson({'roundId': 'rd1'}),
        throwsFormatException,
      );
    });

    test('CatalogSearchResponse cita listu pesama', () {
      final response = CatalogSearchResponse.fromJson({
        'songs': [
          {'title': 'Fuego', 'artist': 'Severina'},
        ],
      });
      expect(response.songs.single.title, 'Fuego');
    });
  });

  group('sobe, runde, snimak', () {
    test('RoomDto prihvata samo dogovorena stanja', () {
      for (final status in RoomStatusCodes.all) {
        final json = {
          'id': 'r1',
          'name': 'Zurka',
          'hostId': 'u9',
          'status': status,
        };
        expect(RoomDto.fromJson(json).toJson(), json);
      }
      expect(
        () => RoomDto.fromJson({
          'id': 'r1',
          'name': 'Zurka',
          'hostId': 'u9',
          'status': 'srusena',
        }),
        throwsFormatException,
      );
    });

    test('vremena idu na mrezu u UTC-u', () {
      final round = RoundDto(
        id: 'rd1',
        roomId: 'r1',
        startsAt: DateTime.utc(2026, 11, 20, 10).toLocal(),
        endsAt: DateTime.utc(2026, 11, 20, 10, 5),
      );
      expect(round.toJson()['startsAt'], '2026-11-20T10:00:00.000Z');
    });

    test('RoomSnapshotDto krug json<->dto', () {
      final json = {
        'room': {'id': 'r1', 'name': 'Zurka', 'hostId': 'u9', 'status': 'open'},
        'round': {
          'id': 'rd1',
          'roomId': 'r1',
          'startsAt': '2026-11-20T10:00:00.000Z',
          'endsAt': '2026-11-20T10:05:00.000Z',
        },
        'proposals': [
          {
            'id': 'p1',
            'roomId': 'r1',
            'song': {'title': 'Fuego', 'artist': 'Severina'},
            'proposedBy': 'u1',
            'proposedAt': '2026-11-20T10:01:00.000Z',
            'status': 'in_voting',
          },
        ],
        'votes': [
          {
            'id': 'v1',
            'roundId': 'rd1',
            'proposalId': 'p1',
            'voterId': 'u2',
            'castAt': '2026-11-20T10:02:00.000Z',
          },
        ],
      };

      final dto = RoomSnapshotDto.fromJson(json);

      expect(dto.proposals.single.song.title, 'Fuego');
      expect(dto.votes, hasLength(1));
      expect(dto.toJson(), json);
    });

    test('RoomListResponse cita sobe', () {
      final list = RoomListResponse.fromJson({
        'rooms': [
          {'id': 'r1', 'name': 'Zurka', 'hostId': 'u9', 'status': 'paused'},
        ],
      });
      expect(list.rooms.single.status, RoomStatusCodes.paused);
    });
  });
}
