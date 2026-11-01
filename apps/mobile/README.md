# RadioRoom — mobilna aplikacija

Aplikacija za ulogu **slušalac**: pregled predloga pesama u sobi, detalj predloga, predlaganje nove pesme i glasanje. Radi kao jedan prijavljeni korisnik (`u1`, prijava stiže u KT2); podaci su lažni i žive u memoriji.

## Pokretanje

Iz korena repozitorijuma:

```sh
flutter pub get
cd apps/mobile
flutter run              # iOS simulator ili Android emulator
flutter run -d chrome    # u pregledaču, bez emulatora
```

Platforme (Android, iOS, veb) već postoje — `flutter create` nije potreban i ne treba ga pokretati (prepisuje `.metadata` i dodaje šablonski test).

## Ekrani i adrese

| Adresa | Ekran |
| --- | --- |
| `/` | preusmerava na `/sobe` |
| `/sobe` | početna: **Napravi sobu** \| **Pridruži se** (lista soba + QR stub) |
| `/soba/:roomId` | soba — tabovi **Pretraga** \| **Glasaj** \| **Trenutno** (swipe + donji bar) |
| `/soba/:roomId/predlog/:id` | detalj predloga, glasanje |
| `/soba/:roomId/novi` | forma novog predloga — ručni unos (sa dna Pretrage) |

Nepoznata adresa prikazuje „Ova stranica ne postoji.“ sa povratkom na sobe.

Tabovi sobe su stanje ekrana (jedna adresa); Glasaj je podrazumevani (sredina).

## Gde šta živi

- `lib/main.dart` — mesto sastavljanja: **jedino** mesto koje zna za lažni repozitorijum. Zamena porta (npr. klijent servera u KT2) menja samo ovaj fajl.
- `lib/router.dart` — rute; `ShellRoute` pravi jedan `ProposalListBloc` po sobi, pa tabovi, detalj i forma dele iste podatke. Tu je i prikaz prekršaja pravila (SnackBar) za sve ekrane sobe. Home (`/sobe`) ima svoj `RoomsBloc`.
- `lib/ui/` — ekrani: samo šalju događaje Bloc-u i crtaju njegovo stanje.
- `lib/data/` — lažni repozitorijum (kašnjenje 800 ms, okidač greške, dve sobe) i demo podaci.
- Pravila su u `packages/domain`, poruke na srpskom u `packages/ui` (`ruleMessage`), tema i čip stanja takođe u `packages/ui`.

Pravilo se proverava na dva mesta, ali se piše na jednom: forma zove pravilo iz domena dok korisnik kuca (poruka odmah), a Bloc ga zove ponovo pre poziva porta (čuvar). Tehnička greška je ekran greške sa „Pokušaj ponovo“; prekršaj pravila je poruka, nikad ekran greške.

## Demo podaci (`lib/data/demo_room.dart`)

Dve demo sobe + lokalno napravljene; prelaz između njih je tab „Pridruži se“ na početnoj (`/sobe`). QR skeniranje stiže u KT2 (dugme pokazuje stub dijalog).

**„Prazna soba“** (`/soba/r2`) — otvorena runda bez ijednog predloga, za prazan prikaz.

**„Petak u Studentskom“** (`/soba/r1`) — 12 predloga u svih 6 stanja. Vremena su relativna u odnosu na pokretanje, pa demo uvek radi isto:

- tekući korisnik `u1` ima 2 aktivna predloga (Đurđevdan, Mesečina) — treći prolazi, četvrti ne;
- „Bohemian Rhapsody“ (Queen) puštena je pre 20 min — ne može ponovo;
- „Kiša pada“ (Partibrejkers) puštena je pre 2 h — može ponovo;
- `u1` u ovoj rundi još nije glasao.

## Demo tok za odbranu

Ekran glavnog toka (Glasaj tab) pokazuje sva 4 stanja: učitavanje (korak 1), podaci (1), prazan prikaz (6) i grešku sa „Pokušaj ponovo“ (7).

1. **Učitavanje → podaci:** `/sobe` → „Pridruži se“ → „Petak u Studentskom“ → spinner (~800 ms), pa Glasaj tab: kartica pobednika, lista glasanja sa brojem glasova; oznaka „Tvoj predlog“ na Đurđevdanu (u glasanju) i Mesečini (u „Na čekanju“).
2. **Detalj:** dodir na red otvara `/soba/r1/predlog/<id>` (ko predlaže, vreme, glasovi; link ako ga pesma ima); strelica nazad vraća listu.
3. **Akcija sa potvrdom:** „Glasaj“ na predlogu u glasanju → dijalog → broj glasova raste. Drugi glas → SnackBar „Tvoj glas u ovoj rundi je već zabeležen.“ (pravilo iz domena).
4. **Pretraga:** FAB „Predloži pesmu“ → Pretraga tab sa otvorenom tastaturom. Kucanje „queen“ pokazuje postojeće (Bohemian) i katalog bez duplikata (Under Pressure). „Predloži“ → povratak na Glasaj. Katalog pesma + pravilo: dva predloga prolaze, treći daje SnackBar limita (pravilo iz domena).
5. **Forma, pravilo pri unosu:** dno Pretrage → „ili unesi pesmu ručno“ → `/novi`. „Bohemian Rhapsody“ / „Queen“ → poruka ispod polja, dugme ugašeno. Isto i za „ bohemian rhapsody “ / „QUEEN“ (domen poredi normalizovano). „Kiša pada“ / „Partibrejkers“ prolazi.
6. **Prazan prikaz:** početna → „Pridruži se“ → „Prazna soba“ → „Još nema predloga — budi prvi!“. Predlog iz Pretrage prebacuje ekran iz praznog prikaza u podatke.
7. **Greška i oporavak:** meni ⋮ → „Simuliraj grešku“ → sledeći zahtev (npr. glas) pada → ekran greške → „Pokušaj ponovo“ vraća podatke.
8. **Napravi sobu:** početna → naziv → ulaz u novu praznu sobu. Prazan naziv → SnackBar „Naziv sobe ne sme biti prazan.“. QR dugme → stub dijalog („stiže u KT2“).

### Izmene uživo — gde se šta menja

- **Pravilo:** limit aktivnih predloga je `limit = 3` u `checkMaxActiveProposals` (`packages/domain/lib/src/rules/proposal_rules.dart`). Promena na 2 menja i proveru u formi, i proveru u Bloc-u, i broj u poruci — bez izmene ekrana.
- **Rok nedavno puštene pesme:** `cooldown` u `checkNotRecentlyPlayed`, isti fajl.
- **Zamena porta:** nova implementacija `ProposalRepository` i jedna linija u `lib/main.dart`; `git diff lib/ui/` ostaje prazan.

## Ikonica

Ikonica je kod: crta je `tool/render_icon_test.dart` (motiv, boja brenda `#5B3FD9`), a `flutter_launcher_icons` pravi sve veličine za platforme (podešavanje u `pubspec.yaml`). Posle izmene, iz `apps/mobile`:

```sh
flutter test tool/render_icon_test.dart   # assets/icon/*.png
dart run flutter_launcher_icons           # Android, iOS, veb
```

Posle drugog koraka vratiti `ios/Runner.xcodeproj/project.pbxproj` (`git checkout`) — alat u verziji 0.14 tamo pogrešno menja jedno podešavanje.

## Testovi

```sh
flutter test    # iz apps/mobile
```

Pokrivaju sva 4 stanja ekrana (sa sopstvenom implementacijom porta u testu — dokaz zamene porta), navigaciju i adrese, detalj, glas sa potvrdom, formu sa pravilima i slanje.
