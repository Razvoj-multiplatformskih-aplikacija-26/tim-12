// Predlog pesme — glavni pojam sistema (odluka O3).
//
// Nosilac stanja iz `proposal_status.dart`: svaki prelaz pravi novi
// `Proposal` sa novim statusom (domen je nepromenljiv, kao i ostali modeli).
// Vreme predlaganja cuva se kao podatak; "sad" uvek stize kao parametar
// pravila, nikad se ne cita sistemski sat.
import 'ids.dart';
import 'proposal_status.dart';

final class Proposal {
  const Proposal({
    required this.id,
    required this.roomId,
    required this.title,
    required this.artist,
    this.externalLink,
    required this.proposedBy,
    required this.proposedAt,
    required this.status,
  });

  final ProposalId id;
  final RoomId roomId;
  final String title;
  final String artist;

  /// Spoljni link (npr. YouTube) za KT3 deep-link pustanje. Opciono u KT1.
  final String? externalLink;
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
    title: title,
    artist: artist,
    externalLink: externalLink,
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
          other.title == title &&
          other.artist == artist &&
          other.externalLink == externalLink &&
          other.proposedBy == proposedBy &&
          other.proposedAt == proposedAt &&
          sameProposalStatus(other.status, status);

  @override
  int get hashCode => Object.hash(
    id,
    roomId,
    title,
    artist,
    externalLink,
    proposedBy,
    proposedAt,
    proposalStatusHash(status),
  );

  @override
  String toString() => 'Proposal($title — $artist)';
}
