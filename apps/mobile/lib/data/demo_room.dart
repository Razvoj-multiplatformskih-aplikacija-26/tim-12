// Demo podaci za lazni repozitorijum (KT1: podaci u memoriji): soba sa
// predlozima i prazna soba (za prazan prikaz uzivo).
//
// Soba sa predlozima: 12 predloga, zastupljeno svih 6 stanja. Vremena su relativna u odnosu na
// [now], pa je runda uvek otvorena kad se aplikacija pokrene, a "pustena
// pre 20 min" uvek u poslednjih sat. Podaci su slozeni tako da se svako
// pravilo moze pokazati uzivo: tekuci korisnik `u1` ima 2 aktivna predloga
// (treci prolazi, cetvrti ne), p8 je pustena nedavno, `u1` jos nije glasao,
// a p6 nije u glasanju.
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Tekuci korisnik demo sobe (u KT1 nema prijave).
const demoUser = UserId('u1');

/// Demo soba sa predlozima.
const demoRoomId = RoomId('r1');

/// Prazna demo soba — za prazan prikaz ekrana glavnog toka uzivo.
const emptyRoomId = RoomId('r2');

/// Demo sobe za brzi prelaz u meniju liste (naziv po sobi).
const demoRooms = {demoRoomId: _demoRoomName, emptyRoomId: _emptyRoomName};

const _demoRoomName = 'Petak u Studentskom';
const _emptyRoomName = 'Prazna soba';

/// Prazna soba: ima otvorenu rundu, ali jos nijedan predlog ni glas.
RoomSnapshot emptyRoom(DateTime now) => RoomSnapshot(
  room: const Room(id: emptyRoomId, name: _emptyRoomName, hostId: UserId('h2')),
  round: Round(
    id: const RoundId('rd-r2'),
    roomId: emptyRoomId,
    startsAt: now.subtract(const Duration(minutes: 1)),
    endsAt: now.add(const Duration(minutes: 9)),
  ),
  proposals: const [],
  votes: const [],
);

RoomSnapshot demoRoom(DateTime now) {
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));

  Proposal proposal(
    String id,
    String title,
    String artist,
    String by,
    ProposalStatus status, {
    required int minutesAgo,
  }) => Proposal(
    id: ProposalId(id),
    roomId: demoRoomId,
    song: Song(title: title, artist: artist),
    proposedBy: UserId(by),
    proposedAt: ago(minutesAgo),
    status: status,
  );

  final round = Round(
    id: const RoundId('rd2'),
    roomId: demoRoomId,
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

  return RoomSnapshot(
    room: const Room(id: demoRoomId, name: _demoRoomName, hostId: UserId('h1')),
    round: round,
    proposals: [
      proposal(
        'p1',
        'Fuego',
        'Eleni Foureira',
        'u2',
        const InVoting(),
        minutesAgo: 9,
      ),
      proposal(
        'p2',
        'Mr. Brightside',
        'The Killers',
        'u3',
        const InVoting(),
        minutesAgo: 8,
      ),
      proposal(
        'p3',
        'Đurđevdan',
        'Bijelo Dugme',
        'u1',
        const InVoting(),
        minutesAgo: 7,
      ),
      proposal(
        'p4',
        'Levitating',
        'Dua Lipa',
        'u4',
        const InVoting(),
        minutesAgo: 6,
      ),
      proposal(
        'p5',
        'Mesečina',
        'Goran Bregović',
        'u1',
        const Proposed(),
        minutesAgo: 2,
      ),
      proposal(
        'p6',
        'Blinding Lights',
        'The Weeknd',
        'u5',
        const Proposed(),
        minutesAgo: 1,
      ),
      proposal(
        'p7',
        'Seven Nation Army',
        'The White Stripes',
        'u2',
        const Winner(),
        minutesAgo: 14,
      ),
      proposal(
        'p8',
        'Bohemian Rhapsody',
        'Queen',
        'u3',
        Played(ago(20)),
        minutesAgo: 30,
      ),
      proposal(
        'p9',
        'Kiša pada',
        'Partibrejkers',
        'u4',
        Played(ago(120)),
        minutesAgo: 130,
      ),
      proposal(
        'p10',
        'Smells Like Teen Spirit',
        'Nirvana',
        'u5',
        const Rejected(),
        minutesAgo: 15,
      ),
      proposal(
        'p11',
        'Billie Jean',
        'Michael Jackson',
        'u2',
        const Rejected(),
        minutesAgo: 16,
      ),
      proposal(
        'p12',
        'Spam Song',
        'Test',
        'u6',
        const Removed(),
        minutesAgo: 5,
      ),
    ],
    votes: [
      vote('v1', 'u2', 'p1'),
      vote('v2', 'u3', 'p1'),
      vote('v3', 'u4', 'p2'),
    ],
  );
}
