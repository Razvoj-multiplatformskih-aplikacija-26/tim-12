// HTTP implementacija porta predloga — Bloc i ekrani se ne menjaju.
//
// Soba iz putanje za glas (`POST /rooms/:id/votes`) ne stize kroz port
// (`vote` nema `roomId`): pamti se soba svake ucitane runde, a `loadRoom`
// Bloc uvek zove pre glasanja (runda mu treba za telo zahteva). Glas za
// nepoznatu rundu je tehnicki kvar, ne odbijanje — Bloc tada nudi samo
// "Pokusaj ponovo".
//
// Identitet (ko predlaze, ko glasa, ko otvara sobu) server cita iz tokena
// iz `Authorization` zaglavlja; portov `proposedBy`/`voterId`/`hostId` se
// zato ne salju — pravila ostaju u domenu, proverava ih Bloc pre poziva.
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mapping/radioroom_mapping.dart';

import 'api_client.dart';

final class HttpProposalRepository implements ProposalRepository {
  HttpProposalRepository(this._api);

  final ApiClient _api;

  /// Soba runde sa poslednjeg `loadRoom` — putanja za glas.
  final Map<RoundId, RoomId> _roomByRound = {};

  @override
  Future<List<Room>> loadRooms() async {
    final json = await _api.getJson('/rooms');
    return [
      for (final room in RoomListResponse.fromJson(json).rooms) room.toDomain(),
    ];
  }

  @override
  Future<RoomSnapshot> loadRoom(RoomId roomId) async {
    final dto = RoomSnapshotDto.fromJson(
      await _api.getJson('/rooms/${roomId.value}'),
    );
    final snapshot = dto.toDomain();
    _roomByRound[snapshot.round.id] = snapshot.room.id;
    return RoomSnapshot(
      room: snapshot.room,
      round: snapshot.round,
      proposals: snapshot.proposals,
      votes: snapshot.votes,
    );
  }

  @override
  Future<Proposal> propose({
    required RoomId roomId,
    required Song song,
    required UserId proposedBy,
  }) async {
    final json = await _api.postJson(
      '/rooms/${roomId.value}/proposals',
      CreateProposalRequest(song: song.toDto()).toJson(),
    );
    return ProposalDto.fromJson(json).toDomain();
  }

  @override
  Future<Vote> vote({
    required RoundId roundId,
    required ProposalId proposalId,
    required UserId voterId,
  }) async {
    final roomId = _roomByRound[roundId];
    if (roomId == null) {
      throw Exception('Nepoznata runda: glasanje trazi ucitanu sobu.');
    }
    final json = await _api.postJson(
      '/rooms/${roomId.value}/votes',
      CastVoteRequest(
        roundId: roundId.value,
        proposalId: proposalId.value,
      ).toJson(),
    );
    return VoteDto.fromJson(json).toDomain();
  }

  @override
  Future<Proposal> removeProposal({
    required RoomId roomId,
    required ProposalId proposalId,
  }) async {
    final json = await _api.postJson(
      '/rooms/${roomId.value}/proposals/${proposalId.value}/remove',
    );
    return ProposalDto.fromJson(json).toDomain();
  }

  @override
  Future<Proposal> withdrawProposal({
    required RoomId roomId,
    required ProposalId proposalId,
  }) async {
    final json = await _api.postJson(
      '/rooms/${roomId.value}/proposals/${proposalId.value}/withdraw',
    );
    return ProposalDto.fromJson(json).toDomain();
  }

  @override
  Future<Room> closeRoom({required RoomId roomId}) async {
    final json = await _api.postJson('/rooms/${roomId.value}/close');
    return RoomDto.fromJson(json).toDomain();
  }

  @override
  Future<Room> createRoom({
    required String name,
    required UserId hostId,
  }) async {
    final json = await _api.postJson(
      '/rooms',
      CreateRoomRequest(name: name).toJson(),
    );
    return RoomDto.fromJson(json).toDomain();
  }
}
