// Lazna implementacija porta: podaci u memoriji, sa kasnjenjem i okidacem
// greske sledeceg zahteva.
//
// Zivi u aplikaciji, a ne u `blocs`: drugi klijent (backoffice) daje svoju
// implementaciju bez dodira zajednickog paketa, a u KT2 je zamenjuje klijent
// servera — Bloc i ekran se ne menjaju. Pravila NISU ovde (ugovor porta):
// sta stigne, to se upise; Bloc ih proverava domenom pre poziva.
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'demo_room.dart';

final class FakeProposalRepository implements ProposalRepository {
  FakeProposalRepository({
    DateTime Function()? clock,
    this.delay = const Duration(milliseconds: 800),
  }) : _clock = clock ?? DateTime.now {
    for (final seed in [demoRoom(_clock()), emptyRoom(_clock())]) {
      _rooms[seed.room.id] = _RoomData(seed);
    }
  }

  final DateTime Function() _clock;

  /// Vestacko kasnjenje svakog zahteva, da se stanje ucitavanja vidi.
  final Duration delay;

  /// Okidac: sledeci zahtev (bilo koji) baca izuzetak, pa se resetuje.
  /// Ekran ga pali stavkom menija "Simuliraj gresku".
  bool failNext = false;

  /// Sobe po ID-ju; svaka sa svojim predlozima i glasovima.
  final Map<RoomId, _RoomData> _rooms = {};
  var _nextProposal = 13;
  var _nextVote = 4;

  @override
  Future<RoomSnapshot> loadRoom(RoomId roomId) async {
    await _request();
    final data = _room(roomId);
    // Kopije, ne unutrasnje liste: kasniji upis ne sme da promeni snimak
    // koji vec drzi stanje Bloc-a.
    return RoomSnapshot(
      room: data.room,
      round: data.round,
      proposals: List.unmodifiable(data.proposals),
      votes: List.unmodifiable(data.votes),
    );
  }

  @override
  Future<Proposal> propose({
    required RoomId roomId,
    required Song song,
    required UserId proposedBy,
  }) async {
    await _request();
    final proposal = Proposal(
      id: ProposalId('p${_nextProposal++}'),
      roomId: roomId,
      song: song,
      proposedBy: proposedBy,
      proposedAt: _clock(),
      status: const Proposed(),
    );
    _room(roomId).proposals.add(proposal);
    return proposal;
  }

  @override
  Future<Vote> vote({
    required RoundId roundId,
    required ProposalId proposalId,
    required UserId voterId,
  }) async {
    await _request();
    final data = _rooms.values.where((r) => r.round.id == roundId).firstOrNull;
    if (data == null) throw Exception('Nepoznata runda: $roundId');
    final vote = Vote(
      id: VoteId('v${_nextVote++}'),
      roundId: roundId,
      proposalId: proposalId,
      voterId: voterId,
      castAt: _clock(),
    );
    data.votes.add(vote);
    return vote;
  }

<<<<<<< HEAD
  _RoomData _room(RoomId roomId) =>
      _rooms[roomId] ?? (throw Exception('Nepoznata soba: $roomId'));

  @override
  Future<List<Room>> loadRooms() async {
    await _request();
    return List.unmodifiable(_rooms.values.map((d) => d.room));
  }

  @override
  Future<Proposal> removeProposal({
    required RoomId roomId,
    required ProposalId proposalId,
  }) async {
    await _request();
    final data = _room(roomId);
    final index = data.proposals.indexWhere((p) => p.id == proposalId);
    if (index < 0) throw Exception('Nepoznat predlog: $proposalId');
    final removed = data.proposals[index].withStatus(const Removed());
    data.proposals[index] = removed;
    return removed;
  }

  @override
  Future<Room> closeRoom({required RoomId roomId}) async {
    await _request();
    final data = _room(roomId);
    data.room = data.room.withStatus(const RoomClosed());
    return data.room;
  }

  /// Zajednicki pocetak svakog zahteva: kasnjenje, pa jednokratna greska.
  Future<void> _request() async {
    await Future<void>.delayed(delay);
    if (failNext) {
      failNext = false;
      throw Exception('Simulirana greska');
    }
  }
}

/// Promenljivi podaci jedne sobe (samo unutar laznog repozitorijuma).
final class _RoomData {
  _RoomData(RoomSnapshot seed)
    : room = seed.room,
      round = seed.round,
      proposals = [...seed.proposals],
      votes = [...seed.votes];

  Room room;
  final Round round;
  final List<Proposal> proposals;
  final List<Vote> votes;
}
