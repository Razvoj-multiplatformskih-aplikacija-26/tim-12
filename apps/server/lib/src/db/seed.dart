// Pocetni podaci: ucitavaju se pri podizanju servera, samo u praznu bazu.
//
// Isti sadrzaj kao lazni podaci iz KT1 (mobilni demo: soba r1 sa 12
// predloga u svih 6 stanja i prazna soba r2; backoffice demo: pauzirana i
// zatvorena soba), sada na jednom mestu za oba klijenta. Vremena su
// relativna u odnosu na trenutak podizanja: runda je otvorena, a pesma
// "pustena pre 20 min" je uvek u poslednjih sat (pravilo se moze pokazati).
//
// Demo nalozi (lozinka za sve: [demoPassword]) — spisak ide i u README:
//   slusaoci: ana (u1), marko (u2), jelena (u3), nikola (u4), sara (u5),
//             spamer (u6, blokiran)
//   hostovi:  luka (h1), mila (h2)
//   moderator: moderator (m1)
import 'package:postgres/postgres.dart';

import '../auth/passwords.dart';

/// Zajednicka lozinka demo naloga (samo razvojni podaci).
const demoPassword = 'demo1234';

/// Upisuje pocetne podatke ako u bazi nema nijednog korisnika. Vraca da li
/// je upisivao. Sve ide u jednoj transakciji: ili ceo skup, ili nista.
Future<bool> seedIfEmpty(
  SessionExecutor db, {
  required PasswordHasher hasher,
  required DateTime now,
}) async {
  final count = await db.run(
    (s) async =>
        (await s.execute('SELECT count(*) FROM users')).first[0]! as int,
  );
  if (count > 0) return false;

  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
  DateTime inMinutes(int minutes) => now.add(Duration(minutes: minutes));

  await db.runTx((tx) async {
    Future<void> insert(String sql, Map<String, Object?> values) =>
        tx.execute(Sql.named(sql), parameters: values);

    for (final (id, username, name, role, blocked) in _users) {
      await insert(
        'INSERT INTO users (id, username, display_name, password_hash, role, '
        'blocked) VALUES (@id, @username, @name, @hash, @role, @blocked)',
        {
          'id': id,
          'username': username,
          'name': name,
          // Svaki nalog dobija sopstvenu so, iako je lozinka ista.
          'hash': hasher.hash(demoPassword),
          'role': role,
          'blocked': blocked,
        },
      );
    }

    for (final (id, name, host, status) in _rooms) {
      await insert(
        'INSERT INTO rooms (id, name, host_id, status) '
        'VALUES (@id, @name, @host, @status)',
        {'id': id, 'name': name, 'host': host, 'status': status},
      );
    }

    // Tekuca runda u otvorenim i pauziranoj sobi; zatvorena ima samo
    // zavrsenu rundu.
    for (final (id, room, startedAgo, endsIn) in _rounds) {
      await insert(
        'INSERT INTO rounds (id, room_id, starts_at, ends_at) '
        'VALUES (@id, @room, @starts, @ends)',
        {
          'id': id,
          'room': room,
          'starts': ago(startedAgo),
          'ends': inMinutes(endsIn),
        },
      );
    }

    for (final p in _proposals) {
      await insert(
        'INSERT INTO proposals (id, room_id, title, artist, cover_url, album, '
        'proposed_by, proposed_at, status, played_at) VALUES (@id, @room, '
        '@title, @artist, @cover, @album, @by, @at, @status, @played)',
        {
          'id': p.id,
          'room': p.room,
          'title': p.title,
          'artist': p.artist,
          'cover': p.coverUrl,
          'album': p.album,
          'by': p.by,
          'at': ago(p.minutesAgo),
          'status': p.status,
          'played': p.playedMinutesAgo == null
              ? null
              : ago(p.playedMinutesAgo!),
        },
      );
    }

    for (final (id, round, proposal, voter) in _votes) {
      await insert(
        'INSERT INTO votes (id, round_id, proposal_id, voter_id, cast_at) '
        'VALUES (@id, @round, @proposal, @voter, @at)',
        {
          'id': id,
          'round': round,
          'proposal': proposal,
          'voter': voter,
          'at': ago(1),
        },
      );
    }
  });
  return true;
}

// (id, korisnicko ime, prikazno ime, uloga, blokiran)
const _users = [
  ('u1', 'ana', 'Ana', 'listener', false),
  ('u2', 'marko', 'Marko', 'listener', false),
  ('u3', 'jelena', 'Jelena', 'listener', false),
  ('u4', 'nikola', 'Nikola', 'listener', false),
  ('u5', 'sara', 'Sara', 'listener', false),
  ('u6', 'spamer', 'Spamer', 'listener', true),
  ('h1', 'luka', 'DJ Luka', 'host', false),
  ('h2', 'mila', 'DJ Mila', 'host', false),
  ('m1', 'moderator', 'Moderator', 'moderator', false),
];

// (id, naziv, host, stanje)
const _rooms = [
  ('r1', 'Petak u Studentskom', 'h1', 'open'),
  ('r2', 'Prazna soba', 'h2', 'open'),
  ('r3', 'Subota kod Mike', 'h1', 'paused'),
  ('r4', 'Prosla nedelja', 'h2', 'closed'),
];

// (id, soba, pocela pre min, istice za min) — negativno = vec istekla.
const _rounds = [
  ('rd2', 'r1', 2, 8),
  ('rd-r2', 'r2', 1, 9),
  ('rd-r3', 'r3', 2, 8),
  ('rd-r4', 'r4', 70, -60),
];

final class _Seed {
  const _Seed(
    this.id,
    this.room,
    this.title,
    this.artist,
    this.by,
    this.status, {
    required this.minutesAgo,
    this.playedMinutesAgo,
    this.coverUrl,
    this.album,
  });

  final String id;
  final String room;
  final String title;
  final String artist;
  final String by;
  final String status;
  final int minutesAgo;
  final int? playedMinutesAgo;
  final String? coverUrl;
  final String? album;
}

// Soba r1 kao mobilni demo: u1 (ana) ima 2 aktivna predloga (treci prolazi,
// cetvrti ne), p8 je pustena pre 20 min, u1 jos nije glasala, p6 nije u
// glasanju.
const _proposals = [
  _Seed(
    'p1',
    'r1',
    'Fuego',
    'Eleni Foureira',
    'u2',
    'in_voting',
    minutesAgo: 9,
  ),
  _Seed(
    'p2',
    'r1',
    'Mr. Brightside',
    'The Killers',
    'u3',
    'in_voting',
    minutesAgo: 8,
  ),
  _Seed(
    'p3',
    'r1',
    'Đurđevdan',
    'Bijelo Dugme',
    'u1',
    'in_voting',
    minutesAgo: 7,
  ),
  _Seed('p4', 'r1', 'Levitating', 'Dua Lipa', 'u4', 'in_voting', minutesAgo: 6),
  _Seed(
    'p5',
    'r1',
    'Mesečina',
    'Goran Bregović',
    'u1',
    'proposed',
    minutesAgo: 2,
  ),
  _Seed(
    'p6',
    'r1',
    'Blinding Lights',
    'The Weeknd',
    'u5',
    'proposed',
    minutesAgo: 1,
  ),
  _Seed(
    'p7',
    'r1',
    'Seven Nation Army',
    'The White Stripes',
    'u2',
    'winner',
    minutesAgo: 14,
  ),
  _Seed(
    'p8',
    'r1',
    'Bohemian Rhapsody',
    'Queen',
    'u3',
    'played',
    minutesAgo: 30,
    playedMinutesAgo: 20,
    coverUrl: 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg',
    album: 'A Night at the Opera (1975)',
  ),
  _Seed(
    'p9',
    'r1',
    'Kiša pada',
    'Partibrejkers',
    'u4',
    'played',
    minutesAgo: 130,
    playedMinutesAgo: 120,
  ),
  _Seed(
    'p10',
    'r1',
    'Smells Like Teen Spirit',
    'Nirvana',
    'u5',
    'rejected',
    minutesAgo: 15,
  ),
  _Seed(
    'p11',
    'r1',
    'Billie Jean',
    'Michael Jackson',
    'u2',
    'rejected',
    minutesAgo: 16,
  ),
  _Seed('p12', 'r1', 'Spam Song', 'Test', 'u6', 'removed', minutesAgo: 5),
  // Pauzirana soba r3 (iz backoffice demoa).
  _Seed(
    'q1',
    'r3',
    'Mesečina',
    'Goran Bregović',
    'u1',
    'proposed',
    minutesAgo: 4,
  ),
  _Seed(
    'q2',
    'r3',
    'Blinding Lights',
    'The Weeknd',
    'u5',
    'in_voting',
    minutesAgo: 6,
  ),
  // Zatvorena soba r4: istorija.
  _Seed(
    'q3',
    'r4',
    'Kiša pada',
    'Partibrejkers',
    'u2',
    'played',
    minutesAgo: 90,
    playedMinutesAgo: 62,
  ),
];

// (id, runda, predlog, glasac)
const _votes = [
  ('v1', 'rd2', 'p1', 'u2'),
  ('v2', 'rd2', 'p1', 'u3'),
  ('v3', 'rd2', 'p2', 'u4'),
];
