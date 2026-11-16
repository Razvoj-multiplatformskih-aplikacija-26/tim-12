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

Sobe: `r1` otvorena (12 predloga u svih 6 stanja, tekuća runda), `r2` otvorena i prazna, `r3` pauzirana, `r4` zatvorena. Vremena su relativna u odnosu na podizanje servera: runda je uvek otvorena, a „Bohemian Rhapsody“ je uvek puštena pre 20 minuta.

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
