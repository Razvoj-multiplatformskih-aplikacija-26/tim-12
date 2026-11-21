# RadioRoom server

Dart server na [Relic](https://pub.dev/packages/relic)-u 1.2.0 nad PostgreSQL bazom. Izvor istine za mobilnu aplikaciju i backoffice: čuva podatke, proverava pravila iz domenskog paketa i izdaje prijave.

## Pokretanje (Docker, jedna komanda)

Iz korena repozitorijuma:

```sh
cp .env.example .env
docker compose up --build
```

Podiže bazu i server. Server pri pokretanju primenjuje migracije iz `migrations/` i, ako je baza prazna, upisuje početne podatke. Provera: `curl localhost:8080/health` → `{"status":"ok"}`.

- Gašenje: `Ctrl+C` ili `docker compose down`.
- Brisanje baze (ponovo prazna, pa ponovo početni podaci): `docker compose down -v`.

## Pokretanje van Docker-a (razvoj)

```sh
docker compose up -d db      # samo baza
cd apps/server
dart run bin/server.dart     # sam čita ../../.env
```

Baza je na računaru izložena na portu **5433** (ne 5432), da ne smeta lokalnom Postgres-u.

## Demo nalozi

Lozinka za sve naloge: `demo1234`

| Korisničko ime | Uloga | Aplikacija | Napomena |
| --- | --- | --- | --- |
| `ana` | slušalac | mobilna | 2 aktivna predloga u sobi r1, još nije glasala |
| `marko` | slušalac | mobilna | |
| `jelena` | slušalac | mobilna | |
| `nikola` | slušalac | mobilna | |
| `sara` | slušalac | mobilna | |
| `spamer` | slušalac | mobilna | blokiran nalog |
| `luka` | host | mobilna | host soba r1 i r3 |
| `mila` | host | mobilna | host soba r2 i r4 |
| `moderator` | moderator | backoffice | sme i u mobilnu (vidi sobu kao slušalac) |

Sobe: `r1` otvorena (12 predloga u svih 6 stanja, tekuća runda), `r2` otvorena i prazna, `r3` pauzirana, `r4` zatvorena. Vremena su relativna u odnosu na podizanje servera: runda u `r1` ističe 8 minuta posle podizanja (posle toga server sam zatvara rundu i otvara sledeću, vidi „Sobe i glasanje“), a „Bohemian Rhapsody“ je puštena 20 minuta pre podizanja.

## Prijava

Bez prijave rade samo `GET /health` i `POST /auth/login`; svaka druga ruta traži zaglavlje `Authorization: Bearer <token>`. Server prijavu proverava pri svakom pozivu i zna ko poziva samo iz nje — identitet iz tela zahteva ne čita.

| Ruta | Telo / odgovor |
| --- | --- |
| `POST /auth/login` | telo `{"username", "password", "app"}`, `app` je `mobile` (podrazumevano) ili `backoffice` → `200 {"token", "expiresAt", "user": {"id", "displayName", "role"}}` |
| `POST /auth/logout` | briše prijavu iz koje je poziv stigao → `204` |
| `GET /auth/me` | korisnik iz prijave → `200 {"id", "displayName", "role"}` (klijent posle ponovnog pokretanja po ovome zna da li sačuvana prijava još važi) |

Prijava važi `SESSION_TTL_MINUTES` minuta (u `.env`, razvojno 60). Ko može u koju aplikaciju odlučuju domenska pravila `checkCanUseMobile` i `checkCanUseBackoffice`.

Greške imaju oblik `{"code", "data"}` — kôd i podaci pravila, bez teksta; poruku za korisnika pravi klijent.

| Status | `code` | Kada |
| --- | --- | --- |
| 400 | `bad_request` | telo prijave nije ispravno |
| 401 | `invalid_credentials` | pogrešno ime ili lozinka (ista greška za oba, da se ne vidi koja imena postoje) |
| 401 | `unauthenticated` | nema tokena, ili je nepoznat (npr. posle odjave) |
| 401 | `session_expired` | prijava je istekla — klijent vraća korisnika na prijavu |
| 403 | `user_blocked` | nalog je blokiran (pri prijavi i na svakoj ruti, i ako je blokiran posle prijave) |
| 403 | `backoffice_not_allowed` | u backoffice ulazi samo moderator; `data.role` je uloga koja je pokušala |

Primer:

```sh
TOKEN=$(curl -s -X POST localhost:8080/auth/login \
  -H 'content-type: application/json' \
  -d '{"username":"ana","password":"demo1234"}' | sed 's/.*"token":"\([^"]*\)".*/\1/')
curl -s localhost:8080/auth/me -H "authorization: Bearer $TOKEN"
curl -s -X POST localhost:8080/auth/logout -H "authorization: Bearer $TOKEN"
```

## Sobe i glasanje

Sve rute traže prijavu. Predlagač i glasač su uvek korisnik iz prijave — `proposedBy` ili `voterId` u telu se ne čitaju. Pre upisa server proverava ista domenska pravila kao Bloc na klijentu (`packages/domain`), istim redom, i odbija poziv mimo aplikacije istim kodom greške.

| Ruta | Telo / odgovor |
| --- | --- |
| `GET /rooms` | `200 {"rooms": [{"id", "name", "hostId", "status"}]}` |
| `GET /rooms/:id` | `200 {"room", "round": {"id", "roomId", "startsAt", "endsAt"}, "proposals": [...], "votes": [...]}` — svi predlozi sobe (i pušteni) i glasovi tekuće runde |
| `POST /rooms/:id/proposals` | telo `{"song": {"title", "artist", "externalLink"?, "durationMs"?, "coverUrl"?, "album"?}}` → `201` predlog u stanju `proposed`; u glasanje ulazi sa sledećom rundom |
| `POST /rooms/:id/votes` | telo `{"roundId", "proposalId"}` → `201 {"id", "roundId", "proposalId", "voterId", "castAt"}` |
| `POST /rooms` | host; telo `{"name"}` → `201` soba (`hostId` je korisnik iz prijave), odmah sa prvom rundom |
| `POST /rooms/:id/proposals/:pid/withdraw` | slušalac povlači **svoj** predlog dok čeka ishod (`proposed` ili `in_voting`) → `200` predlog u stanju `removed` |
| `POST /rooms/:id/proposals/:pid/remove` | samo moderator; bilo čiji nezavršen predlog (`proposed`, `in_voting`, `winner`) → `200` predlog u stanju `removed` |
| `POST /rooms/:id/close` | samo moderator; otvorena ili pauzirana soba → `200` soba u stanju `closed` |

**Ko šta vidi i menja.** Svaki prijavljeni korisnik (svaka uloga) vidi isti snimak sobe, i glasove sa `voterId` (neproziran ID, bez imena), jer klijent nad istim podacima pokreće ista domenska pravila. Bez prijave nema sadržaja. Tuđ zapis menja samo moderator: uklanja bilo čiji predlog dok nije završen (ne pušten, odbijen ili već uklonjen) i zatvara sobu; slušalac i host menjaju samo svoj predlog (povlačenje dok čeka ishod). Ko sme koju akciju je na jednom mestu u domenu (`permissions.dart`), a akcije su posebne rute (`…/remove`, `…/close`), ne `PATCH {status}` — pravilo je prelaz, klijent ne bira ciljno stanje.

Predlog: `{"id", "roomId", "song", "proposedBy", "proposedAt", "status"}`, a pušten i `"playedAt"`. Na mreži su vremena ISO 8601 u UTC, a stanja tekstualni kodovi kao u bazi: predlog `proposed`, `in_voting`, `winner`, `played`, `rejected`, `removed`; soba `open`, `paused`, `closed`.

**Runda.** Pobednika bira server. Kad runda istekne, prvi sledeći pristup sobi (i čitanje) je zatvara, u istoj transakciji u kojoj se piše: predlog sa najviše glasova postaje `winner` (nerešeno: ranije predložen), ostali u glasanju `rejected`, a gubitnici sa bar jednim glasom vraćaju se kao novi predlozi. Otvara se nova runda od `ROUND_MINUTES` minuta (u `.env`, podrazumevano 10) i svi predlozi koji čekaju ulaze u glasanje. Runda bez ijednog glasa nikoga ne odbija. Pauzirana i zatvorena soba ne zatvaraju rundu.

**Istovremeni pozivi.** Svaki pristup sobi zaključa red sobe (`SELECT … FOR UPDATE`) do kraja transakcije, pa se upisi u jednu sobu i zatvaranje runde izvršavaju jedan za drugim: od deset istovremenih predloga preko limita prolazi tačno onoliko koliko pravilo dozvoljava, a runda se zatvara jednom. Pravilo „jedan glas po rundi“ dodatno čuva baza (`UNIQUE(round_id, voter_id)`).

Greške pravila (kôd i podaci iz domenske greške; prevod je u `packages/mapping` (`apiErrorFromRule`), isti koji klijent koristi za poruku, a HTTP status daje `ErrorCodes.httpStatus` iz ugovora):

| Status | `code` | `data` | Kada |
| --- | --- | --- | --- |
| 400 | `bad_request` | | telo nije ispravno (npr. prazan naslov) |
| 403 | `action_not_allowed` | `action`, `role` | uloga ne sme akciju (npr. moderator ne predlaže i ne glasa) |
| 403 | `user_blocked` | | nalog je blokiran |
| 403 | `not_own_proposal` | `proposalId` | slušalac povlači tuđ predlog |
| 404 | `room_not_found` | | soba ne postoji |
| 404 | `proposal_not_found` | | predlog ne postoji u toj sobi |
| 409 | `already_voted_in_round` | `roundId` | slušalac je u ovoj rundi već glasao |
| 422 | `too_many_active_proposals` | `activeCount`, `limit` | već ima 3 aktivna predloga |
| 422 | `recently_played_song` | `title`, `artist`, `playedAt` | pesma je puštena u poslednjih sat |
| 422 | `invalid_vote_target` | `proposalId` | predlog nije u glasanju (ili nije u ovoj sobi) |
| 422 | `room_not_open` | `status` | soba je pauzirana ili zatvorena |
| 422 | `round_closed` | `roundId` | glas za rundu koja je u međuvremenu zatvorena — klijent ponovo učitava sobu i vidi pobednika |
| 422 | `proposal_not_removable` | `proposalId` | predlog je već završen (pušten, odbijen, uklonjen) |
| 422 | `proposal_not_withdrawable` | `proposalId` | predlog više ne čeka ishod (npr. pobednik) |
| 422 | `room_not_closable` | | soba je već zatvorena |
| 422 | `room_name_empty` | | naziv sobe je prazan |

Poziv mimo aplikacije (posle prijave kao `ana`, vidi primer gore):

```sh
H="authorization: Bearer $TOKEN"; J='content-type: application/json'
# pesma puštena pre 20 min: 422 recently_played_song
curl -s -X POST localhost:8080/rooms/r1/proposals -H "$H" -H "$J" -d '{"song":{"title":"Bohemian Rhapsody","artist":"Queen"}}'
# treći aktivni predlog prolazi, četvrti: 422 too_many_active_proposals
curl -s -X POST localhost:8080/rooms/r1/proposals -H "$H" -H "$J" -d '{"song":{"title":"Treca","artist":"Test"}}'
curl -s -X POST localhost:8080/rooms/r1/proposals -H "$H" -H "$J" -d '{"song":{"title":"Cetvrta","artist":"Test"}}'
# glas prolazi, drugi glas u istoj rundi: 409 already_voted_in_round
ROUND=$(curl -s localhost:8080/rooms/r1 -H "$H" | sed 's/.*"round":{"id":"\([^"]*\)".*/\1/')
curl -s -X POST localhost:8080/rooms/r1/votes -H "$H" -H "$J" -d "{\"roundId\":\"$ROUND\",\"proposalId\":\"p1\"}"
curl -s -X POST localhost:8080/rooms/r1/votes -H "$H" -H "$J" -d "{\"roundId\":\"$ROUND\",\"proposalId\":\"p2\"}"
# akcija backoffice-a mimo aplikacije: 403 action_not_allowed (slušalac ne uklanja i ne zatvara)
curl -s -X POST localhost:8080/rooms/r1/proposals/p6/remove -H "$H"
curl -s -X POST localhost:8080/rooms/r1/close -H "$H"
# tuđ predlog (markov p1): 403 not_own_proposal; svoj (p5): 200
curl -s -X POST localhost:8080/rooms/r1/proposals/p1/withdraw -H "$H"
curl -s -X POST localhost:8080/rooms/r1/proposals/p5/withdraw -H "$H"
```

## Katalog pesama (spoljni servis)

Pretragu pesama zove samo server, kroz port `SongCatalog` (`lib/src/catalog/`); ključ `SONG_CATALOG_API_KEY` je samo u `.env` servera. Za KT2 iza porta stoji lažna implementacija (`FakeSongCatalog`, ~20 pesama u memoriji, bez mreže); prava menja jedan red u `bin/server.dart`.

| Ruta | Odgovor |
| --- | --- |
| `GET /catalog/search?q=…` (traži prijavu) | `200 {"songs": [{"title", "artist", "album", "durationMs", "externalLink"}]}` — po naslovu ili izvođaču, bez obzira na velika slova; ništa nađeno = prazan spisak |

| Status | `code` | Kada |
| --- | --- | --- |
| 400 | `bad_request` | `q` nedostaje, prazan je ili duži od 100 znakova |
| 503 | `catalog_unavailable` | servis javi grešku ili ne odgovori za 5 s — klijent kaže da pretraga trenutno nije dostupna |

```sh
curl -s "localhost:8080/catalog/search?q=queen" -H "authorization: Bearer $TOKEN"
```

## CORS (backoffice u pregledaču)

Pregledač pušta veb backoffice (druga adresa od servera) da zove server samo ako server to dozvoli. Dozvoljene adrese su u `CORS_ORIGINS` u `.env`: razvojno `*` (`flutter run -d chrome` bira slučajan port), u produkciji tačna adresa backoffice-a, više njih odvojeno zarezom. `*` je bezbedno jer prijava putuje u zaglavlju `Authorization`, ne u kolačiću. Mobilnu aplikaciju i curl CORS ne dotiče.

Preflight (`OPTIONS`) dobija `204` bez prijave, a CORS zaglavlja nose i odgovori sa greškom — inače bi pregledač sakrio npr. `session_expired`. Provera:

```sh
curl -i -X OPTIONS localhost:8080/auth/login \
  -H 'origin: http://localhost:5000' -H 'access-control-request-method: POST'
```

## Testovi

```sh
docker compose up -d db
cd apps/server && dart test
```

Testovi nad bazom rade svaki u svojoj privremenoj šemi i ne diraju podatke. Bez podignute baze se preskaču; sa `REQUIRE_DB=1` (CI) padaju.
