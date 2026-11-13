-- Pocetna sema RadioRoom baze.
--
-- ID-jevi su tekst (u domenu su String omotnice): server ih pravi kao UUID,
-- a pocetni podaci mogu da koriste citljive vrednosti. Stanja su tekstualni
-- kodovi sa CHECK ogranicenjem — baza odbija stanje koje domen ne poznaje.
-- Sva vremena su `timestamptz` (cuvaju se u UTC).

CREATE TABLE users (
  id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  username      text NOT NULL UNIQUE,
  display_name  text NOT NULL,
  -- Samo hes funkcije za lozinke, nikad sama lozinka.
  password_hash text NOT NULL,
  role          text NOT NULL CHECK (role IN ('listener', 'host', 'moderator')),
  blocked       boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE rooms (
  id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name       text NOT NULL CHECK (btrim(name) <> ''),
  host_id    text NOT NULL REFERENCES users (id),
  status     text NOT NULL DEFAULT 'open'
             CHECK (status IN ('open', 'paused', 'closed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE rounds (
  id        text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  room_id   text NOT NULL REFERENCES rooms (id),
  starts_at timestamptz NOT NULL,
  ends_at   timestamptz NOT NULL,
  CHECK (ends_at > starts_at)
);

CREATE INDEX rounds_room_idx ON rounds (room_id, starts_at);

CREATE TABLE proposals (
  id            text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  room_id       text NOT NULL REFERENCES rooms (id),
  -- Pesma (domenski `Song`).
  title         text NOT NULL,
  artist        text NOT NULL,
  external_link text,
  duration_ms   integer CHECK (duration_ms > 0),
  cover_url     text,
  album         text,
  proposed_by   text NOT NULL REFERENCES users (id),
  proposed_at   timestamptz NOT NULL DEFAULT now(),
  status        text NOT NULL DEFAULT 'proposed'
                CHECK (status IN ('proposed', 'in_voting', 'winner',
                                  'played', 'rejected', 'removed')),
  -- Jedino stanje sa podatkom (`Played.playedAt`): postoji tacno kad je
  -- predlog pusten.
  played_at     timestamptz,
  CHECK ((status = 'played') = (played_at IS NOT NULL))
);

CREATE INDEX proposals_room_idx ON proposals (room_id, proposed_at);

CREATE TABLE votes (
  id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  round_id    text NOT NULL REFERENCES rounds (id),
  proposal_id text NOT NULL REFERENCES proposals (id),
  voter_id    text NOT NULL REFERENCES users (id),
  cast_at     timestamptz NOT NULL DEFAULT now(),
  -- Pravilo "jedan glas po rundi po slusaocu" konacno cuva baza: od dva
  -- istovremena glasa istog slusaoca upisuje se samo jedan.
  CONSTRAINT votes_one_per_round UNIQUE (round_id, voter_id)
);

CREATE INDEX votes_proposal_idx ON votes (proposal_id);

CREATE TABLE sessions (
  -- Hes tokena prijave; sam token zna samo klijent.
  token_hash text PRIMARY KEY,
  user_id    text NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);

CREATE INDEX sessions_user_idx ON sessions (user_id);
