# Tim 12

# Opis sistema
**RadioRoom** je sistem za zajedničko biranje muzike u realnom vremenu. Slušaoci se pridružuju sobi, predlažu pesme i glasaju koja će biti sledeća. Kada runda glasanja istekne, server proglašava pobednika. Host (DJ) pušta pobednika na svom uređaju preko spoljne aplikacije (npr. YouTube) putem deep linka, a pritom en izlazi iz glasanja: sledeća runda počinje odmah. Backoffice služi moderatorima za upravljanje sobama, pesmama i korisnicima.

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

## Ispunjenost zahteva
Postoje tri uloge: **slušalac** predlaže pesme i glasa, **host/DJ** otvara sobu, podešava trajanje runde i pušta pobedničku pesmu, a **moderator** u backoffice-u uklanja neprimerene predloge, zatvara sobe i blokira korisnike.

### 2. Stanja
Glavni pojam je **predlog pesme**. On prolazi kroz stanja *predložena → u glasanju → pobednik → puštena*, a može završiti i kao *odbijena* (izgubila rundu) ili *uklonjena* (uklonio ju je moderator ili host). Soba ima sopstvena stanja: *otvorena*, *pauzirana* i *zatvorena*.

### 3. Pravila
Svaki slušalac ima jedan glas po rundi, najviše 3 aktivna predloga i ne može predložiti pesmu koja je puštena u poslednjih sat vremena. Pobednika određuju glasovi svih slušalaca u sobi, pa ga konačno bira server kada runda istekne. Ako je rezultat nerešen, pobeđuje ranije predložena pesma. Glas koji stigne posle zatvaranja runde se odbacuje.

### 4. Rad bez mreže
Slušalac može predložiti pesmu i bez mreže. Predlog se čuva lokalno i šalje serveru kad se veza vrati: ulazi u tekuću rundu ako je još otvorena, a ako nije, u sledeću. Host bez mreže može označiti pesmu kao puštenu, a ta promena se sinhronizuje naknadno.

### 5. Posao za osoblje
Moderator u backoffice-u radi sa tabelama svih soba, predloga i korisnika istovremeno: filtrira i sortira prijave, pregleda istoriju glasanja po sobi i masovno uklanja predloge ili blokira naloge. Za takav posao potreban je veći ekran.

### 6. Javni sadržaj
Javne sobe, pesma koja se trenutno pušta, istorija puštenih pesama i nedeljne top liste po sobi dostupni su bez prijave. Taj sadržaj ima smisla za pretraživače, na primer kada neko traži „najpuštenije pesme na žurkama“.
