// DTO: oblik tela i odgovora uskladjen sa serverom.
//
// Prijava prati `userJson` i login-odgovor iz `apps/server` (`{token,
// expiresAt, user: {id, displayName, role}}`); predlog, glas, soba, runda
// i snimak sobe prate port `ProposalRepository`/`RoomSnapshot` iz `blocs`.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
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
    });

    test('LoginResponse cita token, rok i korisnika', () {
      final response = LoginResponse.fromJson({
        'token': 't-1',
        'expiresAt': '2026-11-20T12:00:00.000Z',
        'user': {'id': 'u1', 'displayName': 'Ana', 'role': 'listener'},
      });

      expect(response.token, 't-1');
      expect(response.user.displayName, 'Ana');
      expect(response.user.role, Role.listener);
      expect(response.user.blocked, isFalse);
    });

    test('UserDto krug domen<->ugovor', () {
      const user = User(
        id: UserId('u1'),
        displayName: 'Ana',
        role: Role.moderator,
      );

      final dto = UserDto.fromDomain(user);
      expect(dto.toJson(), {
        'id': 'u1',
        'displayName': 'Ana',
        'role': 'moderator',
      });
      expect(dto.toDomain(), user);
      expect(UserDto.fromJson(dto.toJson()).toDomain(), user);
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

  group('predlozi i glasovi', () {
    test('ProposalDto krug domen<->ugovor za svako stanje', () {
      final statuses = <ProposalStatus>[
        const Proposed(),
        const InVoting(),
        const Winner(),
        Played(DateTime.utc(2026, 11, 20, 11, 40)),
        const Rejected(),
        const Removed(),
      ];
      for (final status in statuses) {
        final proposal = Proposal(
          id: const ProposalId('p1'),
          roomId: const RoomId('r1'),
          song: const Song(title: 'Fuego', artist: 'Severina'),
          proposedBy: const UserId('u1'),
          proposedAt: DateTime.utc(2026, 11, 20, 10),
          status: status,
        );

        final back = ProposalDto.fromJson(
          ProposalDto.fromDomain(proposal).toJson(),
        ).toDomain();
        expect(back, proposal);
      }
    });

    test('ProposalDto baca za nepoznato stanje', () {
      expect(
        () => ProposalDto.fromJson({
          'id': 'p1',
          'roomId': 'r1',
          'song': {'title': 'T', 'artist': 'A'},
          'proposedBy': 'u1',
          'proposedAt': '2026-11-20T10:00:00.000Z',
          'status': 'leprsa_u_vazduhu',
        }),
        throwsFormatException,
      );
    });

    test('CreateProposalRequest ne salje identitet predlagaca', () {
      final body = const CreateProposalRequest(
        roomId: RoomId('r1'),
        title: 'Fuego',
        artist: 'Severina',
      ).toJson();

      expect(body['roomId'], 'r1');
      expect((body['song'] as Map)['title'], 'Fuego');
      expect(body.keys, isNot(contains('proposedBy')));
    });

    test('VoteDto krug domen<->ugovor', () {
      final vote = Vote(
        id: const VoteId('v1'),
        roundId: const RoundId('rd1'),
        proposalId: const ProposalId('p1'),
        voterId: const UserId('u1'),
        castAt: DateTime.utc(2026, 11, 20, 10, 5),
      );

      final back = VoteDto.fromJson(VoteDto.fromDomain(vote).toJson());
      expect(back.toDomain(), vote);
    });

    test('CastVoteRequest salje rundu i predlog', () {
      expect(
        const CastVoteRequest(
          roundId: RoundId('rd1'),
          proposalId: ProposalId('p1'),
        ).toJson(),
        {'roundId': 'rd1', 'proposalId': 'p1'},
      );
    });
  });

  group('sobe, runde, snimak', () {
    test('RoomDto krug domen<->ugovor za svako stanje sobe', () {
      for (final status in [const RoomOpen(), const RoomPaused(), const RoomClosed()]) {
        const room = Room(
          id: RoomId('r1'),
          name: 'Zurka',
          hostId: UserId('u9'),
        );
        final withStatus = room.withStatus(status);

        final back = RoomDto.fromJson(
          RoomDto.fromDomain(withStatus).toJson(),
        ).toDomain();
        expect(back, withStatus);
      }
    });

    test('RoundDto krug domen<->ugovor', () {
      final round = Round(
        id: const RoundId('rd1'),
        roomId: const RoomId('r1'),
        startsAt: DateTime.utc(2026, 11, 20, 10),
        endsAt: DateTime.utc(2026, 11, 20, 10, 5),
      );

      final back = RoundDto.fromJson(RoundDto.fromDomain(round).toJson());
      expect(back.toDomain(), round);
    });

    test('RoomSnapshotDto nosi isti oblik kao port RoomSnapshot', () {
      final dto = RoomSnapshotDto.fromJson({
        'room': {
          'id': 'r1',
          'name': 'Zurka',
          'hostId': 'u9',
          'status': 'open',
        },
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
      });

      final snapshot = dto.toDomain();
      expect(snapshot.room.id, const RoomId('r1'));
      expect(snapshot.round.id, const RoundId('rd1'));
      expect(snapshot.proposals, hasLength(1));
      expect(snapshot.proposals.first.song.title, 'Fuego');
      expect(snapshot.votes, hasLength(1));
    });
  });
}
