# RadioRoom backoffice

Moderacija: sobe, predlozi, stanja. Uloga moderator, nad istim paketima
`radioroom_domain` i `radioroom_blocs` kao mobilna aplikacija.

## Pokretanje

```sh
flutter pub get        # iz korena repozitorijuma
cd apps/backoffice
flutter run            # Linux desktop
flutter run -d chrome  # veb (isti build, isti tok)
```

Dodatnih koraka nema. Podaci su lažni, u memoriji (svaki klijent ima svoje,
nisu sinhronizovani — KT1); prijava stiže tek u KT2.

## Tok

`/sobe` → lista soba → ulaz u sobu → tabela predloga + bočni detalj.
Dubinska veza na detalj: `/sobe/:roomId/predlog/:id` (deljiva, radi refresh).

Akcije osoblja (obe traže potvrdu u dijalogu, nepovratne su):

- **Ukloni predlog** — prelaz u `Removed` (samo za nezavršene predloge);
- **Zatvori sobu** — prelaz u `RoomClosed` (dugme u vrhu ekrana + panel).

Prekršaj pravila je SnackBar sa porukom na srpskom (nije ekran greške);
tehnička greška je ekran sa **Pokušaj ponovo**. Stavka menija
**Simuliraj grešku** izaziva grešku sledećeg zahteva (dokaz zamene porta).

## Tastatura (radi bez miša)

| Taster | Efekat |
|---|---|
| `↑` / `↓` | pomeri izbor kroz redove (i kroz sobe na `/sobe`) |
| `Enter` | otvori izabranu sobu (na listi soba) |
| `Delete` | ukloni izabrani predlog (uz dijalog) — radi i taster sa oznakom Delete na Mac tastaturi (Flutter ga vidi kao Backspace) |
| `Esc` | poništi izbor (ili nazad na sobe) |

Fokus je uvek vidljiv: izabrani red je označen, tasteri rade odmah po ulazu.

## Raspored

Ispod 900px širine tabela postaje lista, bez gubitka izbora. Tap na red
otvara detalj u donjem sheet-u sa istim akcijama kao bočni panel (tastatura
u uskom prikazu samo pomera izbor). Filter (Svi/Aktivni/Završeni) i sort
po glasovima menjaju samo prikaz, ne podatke.
