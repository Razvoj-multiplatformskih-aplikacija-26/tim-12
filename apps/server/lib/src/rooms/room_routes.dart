// Citanje soba: `GET /rooms` i `GET /rooms/:id` (traze prijavu, kao svaka
// ruta van `publicPaths`).
//
// Svaki prijavljeni korisnik vidi isti snimak sobe, ukljucujuci glasove sa
// `voterId` (neprozirni ID-jevi, bez imena): klijent nad istim podacima
// pokrece ista domenska pravila (`checkSingleVotePerRound`, `voteTally`).
// Odbaceno: samo zbir glasova — menja port Bloc-a, pa Bloc vise ne bi bio
// isti nad laznim podacima i nad serverom.
//
// Na mrezi: vremena ISO 8601 u UTC, stanja tekstualni kodovi kao u bazi.
// Predlozi sobe idu celi, bez stranica — soba ima desetine predloga.
import 'package:postgres/postgres.dart' show Session;
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:relic/relic.dart';

import '../catalog/catalog_routes.dart' show songJson;
import '../http/json.dart';
import 'room_store.dart';

final class RoomRoutes {
  RoomRoutes({required this.db});

  final Session db;

  void mount(RelicApp app) {
    app
      ..get('/rooms', list)
      ..get('/rooms/:id', show);
  }

  Future<Response> list(Request request) async {
    final rooms = await loadRooms(db);
    return jsonResponse({'rooms': rooms.map(roomJson).toList()});
  }

  Future<Response> show(Request request) async {
    final id = RoomId(request.rawPathParameters[#id]!);
    final view = await loadRoomView(db, id);
    if (view == null) return errorResponse(404, 'room_not_found');
    return jsonResponse({
      'room': roomJson(view.room),
      'round': roundJson(view.round),
      'proposals': view.proposals.map(proposalJson).toList(),
      'votes': view.votes.map(voteJson).toList(),
    });
  }
}

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
