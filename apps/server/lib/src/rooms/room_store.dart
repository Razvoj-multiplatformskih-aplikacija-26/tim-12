// Citanje soba iz baze, kao domenskih objekata.
//
// Redovi baze se ovde prevode u domen (`Room`, `Round`, `Proposal`, `Vote`),
// pa pravila iz domenskog paketa rade nad istim tipovima kao na klijentu.
// Stanja su u bazi tekstualni kodovi (CHECK dozvoljava samo poznate); ovde
// postaju sealed stanja domena.
import 'package:postgres/postgres.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Sve sto klijent treba o jednoj sobi: soba, tekuca runda, svi predlozi
/// (i pusteni — istorija za pravilo „nije pustena u poslednjih sat“) i
/// glasovi tekuce runde. Serverski zapis, ne `RoomSnapshot` iz `blocs`:
/// server ne zavisi od paketa klijenata.
typedef RoomView = ({
  Room room,
  Round round,
  List<Proposal> proposals,
  List<Vote> votes,
});

const _roomColumns = 'id, name, host_id, status';
const _roundColumns = 'id, room_id, starts_at, ends_at';
const _proposalColumns =
    'id, room_id, title, artist, external_link, duration_ms, cover_url, '
    'album, proposed_by, proposed_at, status, played_at';
const _voteColumns = 'id, round_id, proposal_id, voter_id, cast_at';

/// Sve sobe, po nazivu.
Future<List<Room>> loadRooms(Session db) async {
  final rows = await db.execute(
    'SELECT $_roomColumns FROM rooms ORDER BY name, id',
  );
  return rows.map(roomFromRow).toList();
}

/// Soba sa tekucom rundom, predlozima i glasovima, ili `null` kad soba ne
/// postoji. Tekuca runda je poslednja po pocetku.
Future<RoomView?> loadRoomView(Session db, RoomId roomId) async {
  final id = {'id': roomId.value};
  final rooms = await db.execute(
    Sql.named('SELECT $_roomColumns FROM rooms WHERE id = @id'),
    parameters: id,
  );
  if (rooms.isEmpty) return null;

  final rounds = await db.execute(
    Sql.named(
      'SELECT $_roundColumns FROM rounds WHERE room_id = @id '
      'ORDER BY starts_at DESC, id DESC LIMIT 1',
    ),
    parameters: id,
  );
  // Invarijanta: soba uvek ima rundu (pocetni podaci je prave, a nova soba
  // i zatvaranje runde prave sledecu).
  if (rounds.isEmpty) throw StateError('Soba ${roomId.value} nema rundu');
  final round = roundFromRow(rounds.single);

  final proposals = await db.execute(
    Sql.named(
      'SELECT $_proposalColumns FROM proposals WHERE room_id = @id '
      'ORDER BY proposed_at, id',
    ),
    parameters: id,
  );
  final votes = await db.execute(
    Sql.named(
      'SELECT $_voteColumns FROM votes WHERE round_id = @round '
      'ORDER BY cast_at, id',
    ),
    parameters: {'round': round.id.value},
  );

  return (
    room: roomFromRow(rooms.single),
    round: round,
    proposals: proposals.map(proposalFromRow).toList(),
    votes: votes.map(voteFromRow).toList(),
  );
}

/// Red sa kolonama sobe u domenski `Room`.
Room roomFromRow(List<Object?> row) => Room(
  id: RoomId(row[0]! as String),
  name: row[1]! as String,
  hostId: UserId(row[2]! as String),
  status: roomStatusFromCode(row[3]! as String),
);

/// Red sa kolonama runde u domenski `Round`.
Round roundFromRow(List<Object?> row) => Round(
  id: RoundId(row[0]! as String),
  roomId: RoomId(row[1]! as String),
  startsAt: row[2]! as DateTime,
  endsAt: row[3]! as DateTime,
);

/// Red sa kolonama predloga u domenski `Proposal`; pesma se sklapa iz
/// kolona pesme, a `played_at` postaje podatak stanja `Played`.
Proposal proposalFromRow(List<Object?> row) => Proposal(
  id: ProposalId(row[0]! as String),
  roomId: RoomId(row[1]! as String),
  song: Song(
    title: row[2]! as String,
    artist: row[3]! as String,
    externalLink: row[4] as String?,
    durationMs: row[5] as int?,
    coverUrl: row[6] as String?,
    album: row[7] as String?,
  ),
  proposedBy: UserId(row[8]! as String),
  proposedAt: row[9]! as DateTime,
  status: proposalStatusFromCode(row[10]! as String, row[11] as DateTime?),
);

/// Red sa kolonama glasa u domenski `Vote`.
Vote voteFromRow(List<Object?> row) => Vote(
  id: VoteId(row[0]! as String),
  roundId: RoundId(row[1]! as String),
  proposalId: ProposalId(row[2]! as String),
  voterId: UserId(row[3]! as String),
  castAt: row[4]! as DateTime,
);

/// Kod stanja predloga u bazi (i na mrezi) za domensko stanje.
String proposalStatusCode(ProposalStatus status) => switch (status) {
  Proposed() => 'proposed',
  InVoting() => 'in_voting',
  Winner() => 'winner',
  Played() => 'played',
  Rejected() => 'rejected',
  Removed() => 'removed',
};

/// Domensko stanje predloga iz koda; `played` nosi trenutak pustanja.
ProposalStatus proposalStatusFromCode(String code, DateTime? playedAt) =>
    switch (code) {
      'proposed' => const Proposed(),
      'in_voting' => const InVoting(),
      'winner' => const Winner(),
      'played' => Played(playedAt!),
      'rejected' => const Rejected(),
      'removed' => const Removed(),
      _ => throw FormatException('Nepoznato stanje predloga: $code'),
    };

/// Kod stanja sobe u bazi (i na mrezi) za domensko stanje.
String roomStatusCode(RoomStatus status) => switch (status) {
  RoomOpen() => 'open',
  RoomPaused() => 'paused',
  RoomClosed() => 'closed',
};

/// Domensko stanje sobe iz koda.
RoomStatus roomStatusFromCode(String code) => switch (code) {
  'open' => const RoomOpen(),
  'paused' => const RoomPaused(),
  'closed' => const RoomClosed(),
  _ => throw FormatException('Nepoznato stanje sobe: $code'),
};

/// Zakljucava red sobe do kraja transakcije i vraca sobu, ili `null` kad ne
/// postoji. Svi upisi u jednu sobu (i zatvaranje runde) idu jedan za drugim,
/// pa izmedju provere pravila i upisa niko ne moze da se provuce. Zakljucava
/// se jedna soba — ostale sobe rade nesmetano.
Future<Room?> lockRoom(Session tx, RoomId roomId) async {
  final rows = await tx.execute(
    Sql.named('SELECT $_roomColumns FROM rooms WHERE id = @id FOR UPDATE'),
    parameters: {'id': roomId.value},
  );
  return rows.isEmpty ? null : roomFromRow(rows.single);
}

/// Upisuje predlog (sa ID-jem, vremenom i stanjem iz [proposal]).
Future<void> insertProposal(Session tx, Proposal proposal) async {
  final song = proposal.song;
  await tx.execute(
    Sql.named(
      'INSERT INTO proposals (id, room_id, title, artist, external_link, '
      'duration_ms, cover_url, album, proposed_by, proposed_at, status, '
      'played_at) VALUES (@id, @room, @title, @artist, @link, @duration, '
      '@cover, @album, @by, @at, @status, @played)',
    ),
    parameters: {
      'id': proposal.id.value,
      'room': proposal.roomId.value,
      'title': song.title,
      'artist': song.artist,
      'link': song.externalLink,
      'duration': song.durationMs,
      'cover': song.coverUrl,
      'album': song.album,
      'by': proposal.proposedBy.value,
      'at': proposal.proposedAt,
      'status': proposalStatusCode(proposal.status),
      'played': switch (proposal.status) {
        Played(:final playedAt) => playedAt,
        _ => null,
      },
    },
  );
}

/// Menja stanje predloga (bez podatka — `Played` ovde ne prolazi).
Future<void> setProposalStatus(
  Session tx,
  ProposalId id,
  ProposalStatus status,
) async {
  assert(status is! Played, 'pustanje nosi vreme; nije deo KT2');
  await tx.execute(
    Sql.named('UPDATE proposals SET status = @status WHERE id = @id'),
    parameters: {'id': id.value, 'status': proposalStatusCode(status)},
  );
}

/// Upisuje rundu.
Future<void> insertRound(Session tx, Round round) async {
  await tx.execute(
    Sql.named(
      'INSERT INTO rounds (id, room_id, starts_at, ends_at) '
      'VALUES (@id, @room, @starts, @ends)',
    ),
    parameters: {
      'id': round.id.value,
      'room': round.roomId.value,
      'starts': round.startsAt,
      'ends': round.endsAt,
    },
  );
}

/// Upisuje glas. Baza je poslednja brana pravila „jedan glas po rundi“
/// (`votes_one_per_round`): kada je prekrseno, vraca `false` umesto da baci.
Future<bool> insertVote(Session tx, Vote vote) async {
  try {
    await tx.execute(
      Sql.named(
        'INSERT INTO votes (id, round_id, proposal_id, voter_id, cast_at) '
        'VALUES (@id, @round, @proposal, @voter, @at)',
      ),
      parameters: {
        'id': vote.id.value,
        'round': vote.roundId.value,
        'proposal': vote.proposalId.value,
        'voter': vote.voterId.value,
        'at': vote.castAt,
      },
    );
    return true;
  } on ServerException catch (e) {
    if (e.constraintName == 'votes_one_per_round') return false;
    rethrow;
  }
}
