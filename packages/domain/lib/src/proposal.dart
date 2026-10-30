// Predlog pesme — glavni pojam sistema (odluka O3).
//
// Nosilac stanja iz `proposal_status.dart`: svaki prelaz pravi novi
// `Proposal` sa novim statusom (domen je nepromenljiv, kao i ostali modeli).
// Vreme predlaganja cuva se kao podatak; "sad" uvek stize kao parametar
// pravila, nikad se ne cita sistemski sat.
import 'ids.dart';
import 'proposal_status.dart';
import 'song.dart';

final class Proposal {
  const Proposal({
    required this.id,
    required this.roomId,
    required this.song,
    required this.proposedBy,
    required this.proposedAt,
    required this.status,
  });

  final ProposalId id;
  final RoomId roomId;
  final Song song;
  final UserId proposedBy;
  final DateTime proposedAt;
  final ProposalStatus status;

  /// "Aktivan" predlog (odluka O6): ceka ishod runde.
  /// Pobednik/pustena/odbijena/uklonjena imaju zakljucenu sudbinu
  /// i ne trose kvotu od max 3 aktivna predloga.
  bool get isActive => status is Proposed || status is InVoting;

  /// Novi predlog sa promenjenim statusom. Validnost prelaza proverava
  /// `canTransition` — ova metoda samo pravi kopiju, ne sprovodi pravilo.
  Proposal withStatus(ProposalStatus next) => Proposal(
    id: id,
    roomId: roomId,
    song: song,
    proposedBy: proposedBy,
    proposedAt: proposedAt,
    status: next,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Proposal &&
          other.id == id &&
          other.roomId == roomId &&
          other.song == song &&
          other.proposedBy == proposedBy &&
          other.proposedAt == proposedAt &&
          sameProposalStatus(other.status, status);

  @override
  int get hashCode => Object.hash(
    id,
    roomId,
    song,
    proposedBy,
    proposedAt,
    proposalStatusHash(status),
  );

  @override
  String toString() => 'Proposal($song)';
}
