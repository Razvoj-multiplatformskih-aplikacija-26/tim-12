// Snimak sobe — oblik odgovora porta (odluka O1).
//
// Sve sto ekran glavnog toka treba o jednoj sobi, u jednom odgovoru porta.
// Zivi u `blocs`, a ne u `domain`: nije domenski pojam, vec oblik u kome
// podaci stizu kroz port. Equatable jer ga nose stanja Bloc-a.
import 'package:equatable/equatable.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

final class RoomSnapshot extends Equatable {
  const RoomSnapshot({
    required this.room,
    required this.round,
    required this.proposals,
    required this.votes,
  });

  final Room room;

  /// Tekuca runda glasanja.
  final Round round;

  /// Svi predlozi sobe, ukljucujuci pustene — oni su istorija za pravilo
  /// "nije pustena u poslednjih sat".
  final List<Proposal> proposals;

  /// Glasovi tekuce runde.
  final List<Vote> votes;

  @override
  List<Object?> get props => [room, round, proposals, votes];
}
