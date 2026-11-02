// Stanja sobe (odluka: stizu sa backoffice celinom).
//
// Tok: otvorena <-> pauzirana; iz obe u zatvorenu. Zatvorena je terminalna.
// Sealed hijerarhija po istom obrascu kao stanja predloga: `switch` mora
// obraditi svih 3, pa zaboravljeno stanje puca pre pokretanja.
sealed class RoomStatus {
  const RoomStatus();
}

/// Otvorena — slusaoci predlazu i glasaju.
final class RoomOpen extends RoomStatus {
  const RoomOpen();
}

/// Pauzirana — predlozi i glasovi cekaju (npr. pauza zurke).
final class RoomPaused extends RoomStatus {
  const RoomPaused();
}

/// Zatvorena — moderator ili host zavrsio sobu. Terminalno.
final class RoomClosed extends RoomStatus {
  const RoomClosed();
}

/// Jedina funkcija koja kaze koji su prelazi sobe dozvoljeni.
///
/// Sva logika prelaza na jednom mestu: backoffice Bloc i KT2 server je
/// samo pitaju, pa se promena prelaza vidi na jednom diffu.
bool canTransitionRoom(RoomStatus from, RoomStatus to) =>
    switch ((from, to)) {
      (RoomOpen(), RoomPaused()) => true,
      (RoomPaused(), RoomOpen()) => true,
      (RoomOpen(), RoomClosed()) => true,
      (RoomPaused(), RoomClosed()) => true,
      _ => false,
    };
