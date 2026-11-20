// Sobe: citanje (`GET /rooms`, `GET /rooms/:id`), predlaganje
// (`POST /rooms/:id/proposals`) i glasanje (`POST /rooms/:id/votes`). Sve
// traze prijavu, kao svaka ruta van `publicPaths`.
//
// Svaki pristup jednoj sobi je jedna transakcija koja prvo zakljuca sobu i
// zatvori isteklu rundu (`round_closing.dart`), pa tek onda cita ili upisuje.
// Pre upisa server proverava ISTA domenska pravila kao Bloc na klijentu, i
// istim redom; identitet je samo iz prijave (`request.currentUser`), nikad
// iz tela zahteva.
//
// Svaki prijavljeni korisnik vidi isti snimak sobe, ukljucujuci glasove sa
// `voterId` (neprozirni ID-jevi, bez imena): klijent nad istim podacima
// pokrece ista domenska pravila (`checkSingleVotePerRound`, `voteTally`).
// Odbaceno: samo zbir glasova — menja port Bloc-a, pa Bloc vise ne bi bio
// isti nad laznim podacima i nad serverom.
//
// Na mrezi: vremena ISO 8601 u UTC, stanja tekstualni kodovi kao u bazi.
// Predlozi sobe idu celi, bez stranica — soba ima desetine predloga.
import 'package:postgres/postgres.dart' show Session, SessionExecutor;
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:relic/relic.dart';

import '../auth/auth.dart';
import '../catalog/catalog_routes.dart' show songJson;
import '../http/json.dart';
import '../http/rule_errors.dart';
import 'room_store.dart';
import 'round_closing.dart';

/// Najduzi naslov, izvodjac, album ili link pesme.
const maxSongFieldLength = 200;

final class RoomRoutes {
  RoomRoutes({
    required this.db,
    required this.roundLength,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  final SessionExecutor db;

  /// Trajanje nove runde (`ROUND_MINUTES`).
  final Duration roundLength;

  final DateTime Function() _clock;

  void mount(RelicApp app) {
    app
      ..get('/rooms', list)
      ..get('/rooms/:id', show)
      ..post('/rooms/:id/proposals', propose)
      ..post('/rooms/:id/votes', vote);
  }

  Future<Response> list(Request request) async {
    final rooms = await db.run(loadRooms);
    return jsonResponse({'rooms': rooms.map(roomJson).toList()});
  }

  Future<Response> show(Request request) => _inRoom(
    request,
    (tx, view, now) async => jsonResponse(roomViewJson(view)),
  );

  /// Telo: `{song: {title, artist, externalLink?, durationMs?, coverUrl?,
  /// album?}}`. Predlog ulazi u glasanje sa sledecom rundom.
  Future<Response> propose(Request request) async {
    final song = songFromJson((await readJsonObject(request))?['song']);
    if (song == null) return errorResponse(400, 'bad_request');
    final user = request.currentUser;

    return _inRoom(request, (tx, view, now) async {
      final violation = firstViolation([
        checkAllowed(user: user, action: UserAction.propose),
        checkRoomOpen(room: view.room),
        checkMaxActiveProposals(proposals: view.proposals, userId: user.id),
        checkNotRecentlyPlayed(song: song, played: view.proposals, now: now),
      ]);
      if (violation != null) return ruleErrorResponse(violation);

      final proposal = Proposal(
        id: ProposalId(newId()),
        roomId: view.room.id,
        song: song,
        proposedBy: user.id,
        proposedAt: now,
        status: const Proposed(),
      );
      await insertProposal(tx, proposal);
      return jsonResponse(proposalJson(proposal), status: 201);
    });
  }

  /// Telo: `{roundId, proposalId}`. `roundId` je runda za koju klijent misli
  /// da glasa — ako je u medjuvremenu zatvorena, glas je zakasneo.
  Future<Response> vote(Request request) async {
    final body = await readJsonObject(request);
    final roundId = body?['roundId'];
    final proposalId = body?['proposalId'];
    if (roundId is! String || proposalId is! String) {
      return errorResponse(400, 'bad_request');
    }
    final user = request.currentUser;

    return _inRoom(request, (tx, view, now) async {
      final early = firstViolation([
        checkAllowed(user: user, action: UserAction.vote),
        checkRoomOpen(room: view.room),
        checkCurrentRound(current: view.round, roundId: RoundId(roundId)),
      ]);
      if (early != null) return ruleErrorResponse(early);

      final target = view.proposals
          .where((p) => p.id.value == proposalId)
          .firstOrNull;
      // Predlog van ove sobe je za glasanje isto sto i predlog van glasanja.
      if (target == null) {
        return ruleErrorResponse(
          InvalidVoteTarget(proposalId: ProposalId(proposalId)),
        );
      }
      final violation = firstViolation([
        checkVoteTarget(proposal: target),
        checkSingleVotePerRound(
          votes: view.votes,
          voterId: user.id,
          roundId: view.round.id,
        ),
      ]);
      if (violation != null) return ruleErrorResponse(violation);

      final vote = Vote(
        id: VoteId(newId()),
        roundId: view.round.id,
        proposalId: target.id,
        voterId: user.id,
        castAt: now,
      );
      if (!await insertVote(tx, vote)) {
        return ruleErrorResponse(
          AlreadyVotedInRound(voterId: user.id, roundId: view.round.id),
        );
      }
      return jsonResponse(voteJson(vote), status: 201);
    });
  }

  /// Jedna transakcija nad sobom iz putanje: zakljucavanje, zatvaranje
  /// istekle runde, ucitavanje snimka, pa [action]. Nepostojeca soba je
  /// `404 room_not_found`.
  Future<Response> _inRoom(
    Request request,
    Future<Response> Function(Session tx, RoomView view, DateTime now) action,
  ) {
    final roomId = RoomId(request.rawPathParameters[#id]!);
    return db.runTx((tx) async {
      if (await lockRoom(tx, roomId) == null) {
        return errorResponse(404, 'room_not_found');
      }
      final now = _clock();
      var view = (await loadRoomView(tx, roomId))!;
      if (await closeExpiredRound(
        tx,
        view,
        now: now,
        roundLength: roundLength,
      )) {
        view = (await loadRoomView(tx, roomId))!;
      }
      return action(tx, view, now);
    });
  }
}

/// Pesma iz tela zahteva, ili `null` kad oblik ne valja (obavezni naslov i
/// izvodjac, ostalo opciono).
Song? songFromJson(Object? json) {
  if (json is! Map<String, Object?>) return null;
  String? text(String key, {required bool required}) {
    final value = json[key];
    if (value == null && !required) return null;
    if (value is! String) throw const FormatException();
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxSongFieldLength) {
      throw const FormatException();
    }
    return trimmed;
  }

  try {
    final duration = json['durationMs'];
    if (duration != null && (duration is! int || duration <= 0)) return null;
    return Song(
      title: text('title', required: true)!,
      artist: text('artist', required: true)!,
      externalLink: text('externalLink', required: false),
      coverUrl: text('coverUrl', required: false),
      album: text('album', required: false),
      durationMs: duration as int?,
    );
  } on FormatException {
    return null;
  }
}

Map<String, Object?> roomViewJson(RoomView view) => {
  'room': roomJson(view.room),
  'round': roundJson(view.round),
  'proposals': view.proposals.map(proposalJson).toList(),
  'votes': view.votes.map(voteJson).toList(),
};

// Privremeno rucno, kao `userJson` i `songJson`, dok ne stigne
// `packages/contract`.

Map<String, Object?> roomJson(Room room) => {
  'id': room.id.value,
  'name': room.name,
  'hostId': room.hostId.value,
  'status': roomStatusCode(room.status),
};

Map<String, Object?> roundJson(Round round) => {
  'id': round.id.value,
  'roomId': round.roomId.value,
  'startsAt': _time(round.startsAt),
  'endsAt': _time(round.endsAt),
};

Map<String, Object?> proposalJson(Proposal proposal) => {
  'id': proposal.id.value,
  'roomId': proposal.roomId.value,
  'song': {...songJson(proposal.song), 'coverUrl': proposal.song.coverUrl},
  'proposedBy': proposal.proposedBy.value,
  'proposedAt': _time(proposal.proposedAt),
  'status': proposalStatusCode(proposal.status),
  if (proposal.status case Played(:final playedAt)) 'playedAt': _time(playedAt),
};

Map<String, Object?> voteJson(Vote vote) => {
  'id': vote.id.value,
  'roundId': vote.roundId.value,
  'proposalId': vote.proposalId.value,
  'voterId': vote.voterId.value,
  'castAt': _time(vote.castAt),
};

String _time(DateTime time) => time.toUtc().toIso8601String();
