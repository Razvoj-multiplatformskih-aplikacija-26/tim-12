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
| `moderator` | moderator | backoffice | |

Sobe: `r1` otvorena (12 predloga u svih 6 stanja, tekuća runda), `r2` otvorena i prazna, `r3` pauzirana, `r4` zatvorena. Vremena su relativna u odnosu na podizanje servera: runda je uvek otvorena, a „Bohemian Rhapsody“ je uvek puštena pre 20 minuta.

## Testovi

```sh
docker compose up -d db
cd apps/server && dart test
```

Testovi nad bazom rade svaki u svojoj privremenoj šemi i ne diraju podatke. Bez podignute baze se preskaču; sa `REQUIRE_DB=1` (CI) padaju.
