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
    final seed = demoRoom(_clock());
    _room = seed.room;
    _round = seed.round;
    _proposals.addAll(seed.proposals);
    _votes.addAll(seed.votes);
  }

  final DateTime Function() _clock;

  /// Vestacko kasnjenje svakog zahteva, da se stanje ucitavanja vidi.
  final Duration delay;

  /// Okidac: sledeci zahtev (bilo koji) baca izuzetak, pa se resetuje.
  /// Ekran ga pali stavkom menija "Simuliraj gresku".
  bool failNext = false;

  late final Room _room;
  late final Round _round;
  final List<Proposal> _proposals = [];
  final List<Vote> _votes = [];
  var _nextProposal = 13;
  var _nextVote = 4;

  @override
  Future<RoomSnapshot> loadRoom(RoomId roomId) async {
    await _request();
    if (roomId != _room.id) throw Exception('Nepoznata soba: $roomId');
    // Kopije, ne unutrasnje liste: kasniji upis ne sme da promeni snimak
    // koji vec drzi stanje Bloc-a.
    return RoomSnapshot(
      room: _room,
      round: _round,
      proposals: List.unmodifiable(_proposals),
      votes: List.unmodifiable(_votes),
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
    _proposals.add(proposal);
    return proposal;
  }

  @override
  Future<Vote> vote({
    required RoundId roundId,
    required ProposalId proposalId,
    required UserId voterId,
  }) async {
    await _request();
    final vote = Vote(
      id: VoteId('v${_nextVote++}'),
      roundId: roundId,
      proposalId: proposalId,
      voterId: voterId,
      castAt: _clock(),
    );
    _votes.add(vote);
    return vote;
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
