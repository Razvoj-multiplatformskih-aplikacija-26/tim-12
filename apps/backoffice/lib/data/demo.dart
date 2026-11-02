// Demo podaci backoffice-a: 3 sobe u razlicitim stanjima.
//
// KT1: svaki klijent ima svoje podatke, nisu sinhronizovani — ovo je
// namerno SVOJ skup (ne deli se sa mobilnim demoom). Soba r1 nosi svih
// 6 stanja predloga; r2 (pauzirana) i r3 (zatvorena) pokazuju da tabela
// soba ima sta da prikaze i da zatvaranje ima vidljiv efekat.
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Sobe demo skupa.
const demoRooms = [
  Room(
    id: RoomId('r1'),
    name: 'Petak u Studentskom',
    hostId: UserId('h1'),
  ),
  Room(
    id: RoomId('r2'),
    name: 'Subota kod Mike',
    hostId: UserId('h1'),
    status: RoomPaused(),
  ),
  Room(
    id: RoomId('r3'),
    name: 'Prosla nedelja',
    hostId: UserId('h2'),
    status: RoomClosed(),
  ),
];

RoomSnapshot demoRoomSnapshot(Room room, DateTime now) {
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));

  Proposal proposal(
    String id,
    String title,
    String artist,
    String by,
    ProposalStatus status, {
    required int minutesAgo,
  }) =>
      Proposal(
        id: ProposalId(id),
        roomId: room.id,
        song: Song(title: title, artist: artist),
        proposedBy: UserId(by),
        proposedAt: ago(minutesAgo),
        status: status,
      );

  final round = Round(
    id: RoundId('rd-${room.id.value}'),
    roomId: room.id,
    startsAt: ago(2),
    endsAt: now.add(const Duration(minutes: 8)),
  );

  Vote vote(String id, String by, String proposalId) => Vote(
        id: VoteId(id),
        roundId: round.id,
        proposalId: ProposalId(proposalId),
        voterId: UserId(by),
        castAt: ago(1),
      );

  // r1: pun skup, svih 6 stanja (struktura kao mobilni demo, svoj fajl).
  if (room.id == const RoomId('r1')) {
    return RoomSnapshot(
      room: room,
      round: round,
      proposals: [
        proposal('p1', 'Fuego', 'Eleni Foureira', 'u2', const InVoting(),
            minutesAgo: 9),
        proposal('p2', 'Mr. Brightside', 'The Killers', 'u3', const InVoting(),
            minutesAgo: 8),
        proposal('p3', 'Đurđevdan', 'Bijelo Dugme', 'u1', const InVoting(),
            minutesAgo: 7),
        proposal('p4', 'Levitating', 'Dua Lipa', 'u4', const Proposed(),
            minutesAgo: 2),
        proposal('p5', 'Seven Nation Army', 'The White Stripes', 'u2',
            const Winner(), minutesAgo: 14),
        proposal('p6', 'Bohemian Rhapsody', 'Queen', 'u3', Played(ago(20)),
            minutesAgo: 30),
        proposal(
            'p7', 'Kisa pada', 'Partibrejkers', 'u4', Played(ago(120)),
            minutesAgo: 130),
        proposal('p8', 'Smells Like Teen Spirit', 'Nirvana', 'u5',
            const Rejected(), minutesAgo: 15),
        proposal('p9', 'Spam Song', 'Test', 'u6', const Removed(),
            minutesAgo: 5),
      ],
      votes: [
        vote('v1', 'u2', 'p1'),
        vote('v2', 'u3', 'p1'),
        vote('v3', 'u4', 'p2'),
      ],
    );
  }

  // r2/r3: po par predloga, tek da red postoji.
  return RoomSnapshot(
    room: room,
    round: round,
    proposals: [
      proposal('q1', 'Mesečina', 'Goran Bregović', 'u1', const Proposed(),
          minutesAgo: 4),
      proposal('q2', 'Blinding Lights', 'The Weeknd', 'u5', const InVoting(),
          minutesAgo: 6),
    ],
    votes: const [],
  );
}
