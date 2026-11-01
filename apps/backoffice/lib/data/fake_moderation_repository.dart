// Lazna implementacija porta za backoffice: podaci u memoriji, sa
// kasnjenjem i okidacem greske sledeceg zahteva.
//
// Po istom ugovoru kao mobilni fake repo: pravila NISU ovde (sta stigne,
// to se upise); ModerationBloc ih proverava domenom pre poziva. Tri sobe
// iz demoa, svaka sa svojim predlozima i glasovima.
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'demo.dart';

final class FakeModerationRepository implements ProposalRepository {
  FakeModerationRepository({
    DateTime Function()? clock,
    this.delay = const Duration(milliseconds: 500),
  }) : _clock = clock ?? DateTime.now {
    final now = _clock();
    for (final room in demoRooms) {
      final seed = demoRoomSnapshot(room, now);
      _rooms.add(seed.room);
      _snapshots[room.id] = seed;
    }
  }

  final DateTime Function() _clock;

  /// Vestacko kasnjenje svakog zahteva, da se stanje ucitavanja vidi.
  final Duration delay;

  /// Okidac: sledeci zahtev (bilo koji) baca izuzetak, pa se resetuje.
  /// Ekran ga pali stavkom menija "Simuliraj gresku".
  bool failNext = false;

  final List<Room> _rooms = [];
  final Map<RoomId, RoomSnapshot> _snapshots = {};

  @override
  Future<List<Room>> loadRooms() async {
    await _request();
    return List.unmodifiable(_rooms);
  }

  @override
  Future<RoomSnapshot> loadRoom(RoomId roomId) async {
    await _request();
    final snapshot = _snapshots[roomId];
    if (snapshot == null) throw Exception('Nepoznata soba: $roomId');
    return RoomSnapshot(
      room: snapshot.room,
      round: snapshot.round,
      proposals: List.unmodifiable(snapshot.proposals),
      votes: List.unmodifiable(snapshot.votes),
    );
  }

  @override
  Future<Proposal> removeProposal({
    required RoomId roomId,
    required ProposalId proposalId,
  }) async {
    await _request();
    final snapshot = _snapshots[roomId];
    if (snapshot == null) throw Exception('Nepoznata soba: $roomId');
    final index = snapshot.proposals.indexWhere((p) => p.id == proposalId);
    if (index < 0) throw Exception('Nepoznat predlog: $proposalId');
    final removed =
        snapshot.proposals[index].withStatus(const Removed());
    _snapshots[roomId] = RoomSnapshot(
      room: snapshot.room,
      round: snapshot.round,
      proposals: [
        for (var i = 0; i < snapshot.proposals.length; i++)
          if (i == index) removed else snapshot.proposals[i],
      ],
      votes: snapshot.votes,
    );
    return removed;
  }

  @override
  Future<Room> closeRoom({required RoomId roomId}) async {
    await _request();
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) throw Exception('Nepoznata soba: $roomId');
    final closed = _rooms[index].withStatus(const RoomClosed());
    _rooms[index] = closed;
    final snapshot = _snapshots[roomId];
    if (snapshot != null) {
      _snapshots[roomId] = RoomSnapshot(
        room: closed,
        round: snapshot.round,
        proposals: snapshot.proposals,
        votes: snapshot.votes,
      );
    }
    return closed;
  }

  @override
  Future<Proposal> propose({
    required RoomId roomId,
    required Song song,
    required UserId proposedBy,
  }) =>
      throw UnimplementedError('Backoffice ne predlaze pesme.');

  @override
  Future<Vote> vote({
    required RoundId roundId,
    required ProposalId proposalId,
    required UserId voterId,
  }) =>
      throw UnimplementedError('Backoffice ne glasa.');

  /// Zajednicki pocetak svakog zahteva: kasnjenje, pa jednokratna greska.
  Future<void> _request() async {
    await Future<void>.delayed(delay);
    if (failNext) {
      failNext = false;
      throw Exception('Simulirana greska');
    }
  }
}
