// Port repozitorijuma predloga — granica izmedju Bloc-a i izvora podataka.
//
// Jedini put podataka do Bloc-a. Implementacija zivi u aplikaciji (KT1:
// lazna, u memoriji); u KT2 je zamenjuje klijent servera, a Bloc i ekran
// se ne menjaju — to je dokaz razdvajanja na odbrani.
//
// Tehnicki neuspeh implementacija prijavljuje bacanjem [Exception].
// Pravila NISU posao implementacije: Bloc ih proverava domenom pre poziva.
import 'package:radioroom_domain/radioroom_domain.dart';

import 'room_snapshot.dart';

abstract interface class ProposalRepository {
  /// Ucitava sobu sa tekucom rundom, predlozima i glasovima.
  Future<RoomSnapshot> loadRoom(RoomId roomId);

  /// Pravi novi predlog i vraca ga. ID i vreme predlaganja dodeljuje
  /// implementacija (u KT2 server ubrizgava pravo vreme).
  Future<Proposal> propose({
    required RoomId roomId,
    required Song song,
    required UserId proposedBy,
  });

  /// Belezi glas i vraca ga. ID i trenutak glasa dodeljuje implementacija.
  Future<Vote> vote({
    required RoundId roundId,
    required ProposalId proposalId,
    required UserId voterId,
  });

  /// Lista svih soba (moderatorski pregled).
  Future<List<Room>> loadRooms();

  /// Uklanja predlog (prelaz u `Removed`) i vraca ga. Pravilo uklanjanja
  /// proverava Bloc domenom pre poziva — port samo izvrsava.
  Future<Proposal> removeProposal({
    required RoomId roomId,
    required ProposalId proposalId,
  });

  /// Zatvara sobu (prelaz u `RoomClosed`) i vraca je. Prelaz proverava Bloc.
  Future<Room> closeRoom({required RoomId roomId});
}
