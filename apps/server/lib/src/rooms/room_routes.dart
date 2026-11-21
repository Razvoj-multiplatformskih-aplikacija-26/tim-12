// Sobe: citanje (`GET /rooms`, `GET /rooms/:id`), predlaganje i glasanje,
// akcije moderatora (zatvaranje sobe, uklanjanje predloga), povlacenje
// svog predloga i nova soba. Sve traze prijavu, kao svaka ruta van
// `publicPaths`.
//
// Akcije su posebne rute (`…/remove`, `…/close`), a ne `PATCH {status}`:
// pravilo je prelaz, ne polje — klijent ne bira ciljno stanje.
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
// Na mrezi: tela zahteva i odgovora su DTO-i iz `packages/contract`, a
// prevod domen <-> DTO je `packages/mapping` (`toDto()`, `toDomain()`) —
// isti prevod koji koriste klijenti. Predlozi sobe idu celi, bez stranica —
// soba ima desetine predloga.
import 'package:postgres/postgres.dart' show Session, SessionExecutor;
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mapping/radioroom_mapping.dart';
import 'package:relic/relic.dart';

import '../auth/auth.dart';
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
      ..post('/rooms', create)
      ..post('/rooms/:id/proposals', propose)
      ..post('/rooms/:id/votes', vote)
      ..post('/rooms/:id/close', close)
      ..post('/rooms/:id/proposals/:pid/remove', remove)
      ..post('/rooms/:id/proposals/:pid/withdraw', withdraw);
  }

  Future<Response> list(Request request) async {
    final rooms = await db.run(loadRooms);
    return jsonResponse(
      RoomListResponse(rooms: [for (final room in rooms) room.toDto()])
          .toJson(),
    );
  }

  Future<Response> show(Request request) => _inRoom(
    request,
    (tx, view, now) async => jsonResponse(
      roomSnapshotToDto(
        room: view.room,
        round: view.round,
        proposals: view.proposals,
        votes: view.votes,
      ).toJson(),
    ),
  );

  /// Telo: `CreateProposalRequest` (`{song: {title, artist, externalLink?,
  /// durationMs?, coverUrl?, album?}}`). Predlog ulazi u glasanje sa
  /// sledecom rundom.
  Future<Response> propose(Request request) async {
    final body = await readRequest(request, CreateProposalRequest.fromJson);
    final song = body == null ? null : validSong(body.song);
    if (song == null) return errorResponse(ErrorCodes.badRequest);
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
      return jsonResponse(proposal.toDto().toJson(), status: 201);
    });
  }

  /// Telo: `CastVoteRequest` (`{roundId, proposalId}`). `roundId` je runda
  /// za koju klijent misli da glasa — ako je u medjuvremenu zatvorena, glas
  /// je zakasneo.
  Future<Response> vote(Request request) async {
    final body = await readRequest(request, CastVoteRequest.fromJson);
    if (body == null) return errorResponse(ErrorCodes.badRequest);
    final CastVoteRequest(:roundId, :proposalId) = body;
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
      return jsonResponse(vote.toDto().toJson(), status: 201);
    });
  }

  /// Telo: `CreateRoomRequest` (`{name}`). Sobu otvara host; host je
  /// korisnik iz prijave, a soba odmah dobija prvu rundu (soba bez runde
  /// ne postoji).
  Future<Response> create(Request request) async {
    final body = await readRequest(request, CreateRoomRequest.fromJson);
    if (body == null) return errorResponse(ErrorCodes.badRequest);
    final name = body.name;
    final user = request.currentUser;

    final violation = firstViolation([
      checkAllowed(user: user, action: UserAction.createRoom),
      checkRoomName(name: name),
    ]);
    if (violation != null) return ruleErrorResponse(violation);

    final now = _clock();
    final room = Room(id: RoomId(newId()), name: name.trim(), hostId: user.id);
    await db.runTx((tx) async {
      await insertRoom(tx, room);
      await insertRound(
        tx,
        Round(
          id: RoundId(newId()),
          roomId: room.id,
          startsAt: now,
          endsAt: now.add(roundLength),
        ),
      );
    });
    return jsonResponse(room.toDto().toJson(), status: 201);
  }

  /// Moderator zatvara sobu; zatvorena soba ne prima predloge ni glasove.
  /// Prelaz proverava isto pravilo stanja sobe kao `ModerationBloc`.
  Future<Response> close(Request request) {
    final user = request.currentUser;
    return _inRoom(request, (tx, view, now) async {
      final allowed = checkAllowed(user: user, action: UserAction.closeRoom);
      if (allowed.error case final error?) return ruleErrorResponse(error);
      if (!canTransitionRoom(view.room.status, const RoomClosed())) {
        return ruleErrorResponse(const RoomNotClosable());
      }

      final closed = view.room.withStatus(const RoomClosed());
      await setRoomStatus(tx, closed.id, closed.status);
      return jsonResponse(closed.toDto().toJson());
    });
  }

  /// Moderator uklanja nezavrsen predlog (bilo ciji).
  Future<Response> remove(Request request) {
    final user = request.currentUser;
    return _inProposal(request, (tx, proposal) async {
      final violation = firstViolation([
        checkAllowed(user: user, action: UserAction.removeProposal),
        checkRemovable(proposal: proposal),
      ]);
      if (violation != null) return ruleErrorResponse(violation);
      return _markRemoved(tx, proposal);
    });
  }

  /// Slusalac povlaci SVOJ predlog dok ceka ishod; tudj predlog server
  /// odbija (`not_own_proposal`). Povucen predlog prelazi u `removed` —
  /// domen nema posebno stanje, a `canTransition` taj prelaz vec dozvoljava.
  Future<Response> withdraw(Request request) {
    final user = request.currentUser;
    return _inProposal(request, (tx, proposal) async {
      final outcome = checkCanWithdraw(user: user, proposal: proposal);
      if (outcome.error case final error?) return ruleErrorResponse(error);
      return _markRemoved(tx, proposal);
    });
  }

  Future<Response> _markRemoved(Session tx, Proposal proposal) async {
    final removed = proposal.withStatus(const Removed());
    await setProposalStatus(tx, removed.id, removed.status);
    return jsonResponse(removed.toDto().toJson());
  }

  /// Kao [_inRoom], za predlog iz putanje (`:pid`) u toj sobi; predlog van
  /// sobe je `404 proposal_not_found`.
  Future<Response> _inProposal(
    Request request,
    Future<Response> Function(Session tx, Proposal proposal) action,
  ) {
    final proposalId = request.rawPathParameters[#pid]!;
    return _inRoom(request, (tx, view, now) async {
      final proposal = view.proposals
          .where((p) => p.id.value == proposalId)
          .firstOrNull;
      if (proposal == null) return errorResponse(ErrorCodes.proposalNotFound);
      return action(tx, proposal);
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
        return errorResponse(ErrorCodes.roomNotFound);
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

/// Pesma iz tela zahteva, ili `null` kad polja ne valjaju: naslov i
/// izvodjac su obavezni, svaki tekst je posle `trim` neprazan i najvise
/// [maxSongFieldLength] znakova, trajanje je pozitivno. Tipove polja je vec
/// proverio `SongDto.fromJson`.
Song? validSong(SongDto dto) {
  String? text(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxSongFieldLength) {
      throw const FormatException();
    }
    return trimmed;
  }

  final duration = dto.durationMs;
  if (duration != null && duration <= 0) return null;
  try {
    return Song(
      title: text(dto.title)!,
      artist: text(dto.artist)!,
      externalLink: text(dto.externalLink),
      coverUrl: text(dto.coverUrl),
      album: text(dto.album),
      durationMs: duration,
    );
  } on FormatException {
    return null;
  }
}
