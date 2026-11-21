# Tim 12

# Opis sistema
**RadioRoom** je sistem za zajedničko biranje muzike u realnom vremenu. Slušaoci se pridružuju sobi, predlažu pesme i glasaju koja će biti sledeća. Kada runda glasanja istekne, server proglašava pobednika. Host (DJ) pušta pobednika na svom uređaju preko spoljne aplikacije (npr. YouTube) putem deep linka, a pritom ne izlazi iz glasanja: sledeća runda počinje odmah. Backoffice služi moderatorima za upravljanje sobama, pesmama i korisnicima.

## Tim
 Ime i prezime | Broj indeksa | GitHub |
| --- | --- | --- |
| Pavle Pantić | _SI 94/24_ | [@pantic236](https://github.com/pantic236) |
| Đorđe Filipović | _SI 73/24_ | [@DjordjeFilipovic21](https://github.com/DjordjeFilipovic21) |

## Delovi sistema

Svi delovi su napisani u Dartu i koriste isti domenski paket sa modelima, stanjima i pravilima.

| Deo | Tehnologija | Namena |
| --- | --- | --- |
| Mobilna aplikacija | Flutter (Android, iOS) | Slušaoci i host: pridruživanje sobi, predlozi, glasanje, puštanje pesme |
| Backoffice | Flutter (veb, desktop) | Moderatori: sobe, pesme, prijave, korisnici |
| Server | Dart | Čuva podatke, sprovodi pravila, zatvara runde i bira pobednika |
| Javni veb | Jaspr | Javne sobe, trenutno puštena pesma, istorija i top liste |
| TV | TBA | TBA |
| Car app | TBA | TBA |

## Ispunjenost zahteva

### 1. Uloge
Postoje tri uloge: **slušalac** predlaže pesme i glasa, **host/DJ** otvara sobu, podešava trajanje runde i pušta pobedničku pesmu, a **moderator** u backoffice-u uklanja neprimerene predloge, zatvara sobe i blokira korisnike.

### 2. Stanja
Glavni pojam je **predlog pesme**. On prolazi kroz stanja *predložena → u glasanju → pobednik → puštena*, a može završiti i kao *odbijena* (izgubila rundu) ili *uklonjena* (uklonio ju je moderator ili host). Soba ima sopstvena stanja: *otvorena*, *pauzirana* i *zatvorena*.

Domenska šema (paket `packages/domain`, zajednički za sve klijente):

```text
POJMOVI I VEZE

User (prikazno ime) ── predlaže ──────► Proposal ── nosi ──► Song (naslov, izvođač, spoljni link*)
                          ▲   │
                     za   │   │ takmiči se u
                          │   ▼
Vote (ko, kad) ───────────┘  Round (početak, kraj) ── u ──► Room (naziv, host)

* opciono — priprema KT3 deep-link puštanja
```

```text
STANJA PREDLOGA (canTransition)

 predložena ──► u glasanju ──► pobednik ──► puštena
                  │              │
                  │              └────────────► uklonjena ◄─── (i iz "predložena")
                  └─► odbijena
                         │
                         └─ carryOver: sa bar 1 glasom vraća se u sledeću rundu
                            kao NOVA "predložena" (nov ID, novo vreme; kap 5 po rangu;
                            bez glasova ispada)
```

### 3. Pravila
Svaki slušalac ima jedan glas po rundi, najviše 3 aktivna predloga i ne može predložiti pesmu koja je puštena u poslednjih sat vremena. Pobednika određuju glasovi svih slušalaca u sobi, pa ga konačno bira server kada runda istekne. Ako je rezultat nerešen, pobeđuje ranije predložena pesma. Glas koji stigne posle zatvaranja runde se odbacuje. Predlozi koji su izgubili rundu, a imali su bar jedan glas, vraćaju se u sledeću rundu kao novi predlozi (najviše 5, po rangu iz izgubljene runde).

### 4. Rad bez mreže
Slušalac može predložiti pesmu i bez mreže. Predlog se čuva lokalno i šalje serveru kad se veza vrati: ulazi u tekuću rundu ako je još otvorena, a ako nije, u sledeću. Host bez mreže može označiti pesmu kao puštenu, a ta promena se sinhronizuje naknadno.

### 5. Posao za osoblje
Moderator u backoffice-u radi sa tabelama svih soba, predloga i korisnika istovremeno: filtrira i sortira prijave, pregleda istoriju glasanja po sobi i masovno uklanja predloge ili blokira naloge. Za takav posao potreban je veći ekran.

### 6. Javni sadržaj
Javne sobe, pesma koja se trenutno pušta, istorija puštenih pesama i nedeljne top liste po sobi dostupni su bez prijave. Taj sadržaj ima smisla za pretraživače, na primer kada neko traži „najpuštenije pesme na žurkama".

## Pokretanje

Uslov: Flutter SDK (Dart ≥ 3.10, provereno sa Flutter 3.47.8) i Docker (za bazu i server).

### Ceo sistem (KT2): baza + server + aplikacije

```sh
cp .env.example .env
docker compose up --build   # baza (PostgreSQL) + server; migracije i demo podaci sami
curl localhost:8080/health  # -> {"status":"ok"}
```

- Gašenje: `Ctrl+C` ili `docker compose down`; brisanje baze (ponovo prazna, pa ponovo demo podaci): `docker compose down -v`.
- Baza je na računaru izložena na portu **5433** (ne 5432), da ne smeta lokalnom Postgres-u; server sluša na **8080**.
- Razvojna varijanta (bez Docker build-a servera): `docker compose up -d db` (samo baza), pa `cd apps/server && dart run bin/server.dart` — server sam čita `../../.env`.

### Aplikacije nad serverom

```sh
flutter pub get          # iz korena: resava sve pakete odjednom (jedan pubspec.lock)
cd apps/mobile
flutter run              # mobilna aplikacija (Android/iOS)
flutter run -d chrome    # mobilna u pregledacu (bez emulatora)
cd ../backoffice
flutter run              # backoffice (Linux/macOS desktop; za veb: flutter run -d chrome)
```

Podrazumevano aplikacije gađaju `http://localhost:8080`. Za drugu adresu (telefon na istoj mreži, udaljeni server) bez editovanja koda:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080
```

Za veb pokretanje potreban je Chrome/Chromium (`CHROME_EXECUTABLE` pokazuje na njega ako nije na podrazumevanoj putanji). Android emulator zahteva Android SDK (uputstvo: `flutter doctor`). macOS desktop i iOS simulator zahtevaju Xcode 15 ili noviji.

Bez servera aplikacije rade protiv ugrađenih lažnih podataka samo u testovima; na pokretanju uvek zovu server i bez njega pokazuju poruku o nedostupnosti umesto večnog učitavanja.

## Demo nalozi (KT2)

Lozinka za sve naloge: `demo1234` (u bazi su samo bcrypt heševi). Prijava preživljava restart (token u bezbednom skladištu), ističe posle 60 minuta, briše se odjavom.

| Korisničko ime | Uloga | Aplikacija |
| --- | --- | --- |
| ana, marko, jelena, nikola, sara | slušalac | mobilna |
| spamer | slušalac, blokiran (odbija ga i prijava) | — |
| luka, mila | host | mobilna |
| moderator | moderator | backoffice (slušaoca odbija rečima) |

Sobe iz demo podataka: `r1` „Petak u Studentskom" (puna, sva stanja predloga), `r2` „Prazna soba" (prazan prikaz), plus pauzirana i zatvorena soba za backoffice tok.

## Pravila i ko ih čuva (KT2)

Pravila žive samo u `packages/domain` — klijent i server ih pozivaju, niko ih ne ponavlja. Klijent proverava formu pre poziva (brza povratna poruka), server proverava isto pravilo pre upisa (konačna odluka, radi i pri istovremenim pozivima), baza čuva ono što se ne da trkom (UNIQUE glas po rundi).

| Pravilo | Forma (klijent) | Upis (server) | Baza |
| --- | --- | --- | --- |
| 1 glas po rundi | `checkSingleVotePerRound` | isto + 409 na trku | UNIQUE `(round_id, voter_id)` |
| max 3 aktivna predloga | `checkMaxActiveProposals` | isto | — |
| nije puštena u poslednji sat | `checkNotRecentlyPlayed` | isto (server ubrizgava pravo vreme) | — |
| glas samo za predlog u glasanju | `checkVoteTarget` | isto + provera da predlog pripada sobi | statusi kao CHECK |
| glas samo za tekuću rundu | — (nema šta da proveri unapred) | `checkCurrentRound` → `round_closed` | — |
| samo otvorena soba prima novo | prikaz stanja | `checkRoomOpen` → `room_not_open` | status CHECK |
| svoj predlog se povlači sam | — | `checkCanWithdraw` (+ `not_own_proposal`) | — |
| moderator uklanja/zatvara | — | `checkAllowed` + `checkRemovable` | — |
| uloga → aplikacija | poruka iz koda | `checkCanUseMobile` / `checkCanUseBackoffice` | role CHECK |

Odbijen poziv nosi kod i podatke pravila (`{code, data}`, bez teksta); poruku na srpskom pravi klijent iz koda (`packages/ui`), nepoznat kod pada na opštu poruku umesto da sruši staru verziju. Klijent posle odbijanja automatski ponovo učitava sobu, pa zakasneli klijent odmah vidi sveže stanje (pobednika i novu rundu).

## Ugovor klijent–server (KT2)

Ugovor je u `packages/contract` (čist Dart, bez zavisnosti — ne uvozi domen, Flutter ni `dart:io`, što proverava `purity_test.dart`; radi na VM-u i u pregledaču): `ApiError{code, data}`, `ErrorCodes` sa HTTP statusom za svaki kôd, DTO zahteva i odgovora sa običnim poljima (ID-jevi i stanja kao stringovi, vremena ISO 8601 u UTC). Prevod domen↔ugovor, u oba smera i za greške, je na jednom mestu u `packages/mapping` (`proposal.toDto()`, `dto.toDomain()`, `apiErrorFromRule`, `ruleErrorFromApi`); koriste ga i klijenti (`api_client`, `ui`) i server. Zavisnosti: `mapping` → `domain` + `contract`; `contract` ni od čega.

Server rute (`apps/server`, Relic 1.2.0): `GET /health`, `POST /auth/login|logout`, `GET /auth/me`, `GET /rooms`, `GET /rooms/:id`, `POST /rooms`, `POST /rooms/:id/proposals|votes|close`, `POST /rooms/:id/proposals/:pid/remove|withdraw`. Prijava ide u `Authorization: Bearer` headeru — server identitet čita samo iz prijave, nikad iz tela zahteva.

## Odluke para (KT2)

- Sesije su neprozirni tokeni (32 slučajna bajta, u bazi samo SHA-256 heš) sa TTL-om — odbačen JWT jer se ne može opozvati pre isteka; istekle sesije se brišu lenjo pri lookup-u.
- Akcije su posebne rute (`…/remove`, `…/close`), a ne `PATCH {status}`: pravilo je prelaz stanja, klijent ne bira ciljno stanje.
- Prevod ugovor↔domen je u posebnom paketu `packages/mapping`, a ne u ugovoru: ugovor tako ne zna za domen (zahtev KT2), a i server i klijenti prevode istim kodom. Odbačeno: prevod u samom `contract`-u (ugovor bi morao da uvozi domen) i ručni JSON na serveru (dva mesta koja moraju da se slažu — razlika se vidi tek u radu).
- Posle odbijanja klijent radi automatski reload (bez pritiska "Pokušaj ponovo"): odbrana pokazuje razlog + sveže stanje u jednom koraku.
- Token stoji u bezbednom skladištu platforme (`flutter_secure_storage`), lozinka se nigde ne čuva; lažni repozitorijumi ostaju u repu za demo bez servera.
- Odbačeno: zbir glasova umesto pojedinačnih u snimku sobe — menjao bi port Bloc-a, pa Bloc više ne bi bio isti nad lažnim podacima i nad serverom.
