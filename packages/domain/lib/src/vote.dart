// Glas — ko je, za koji predlog, u kojoj rundi i kada (odluka O2).
//
// Zasebna klasa (a ne brojac na predlogu) da bi pravila "jedan glas po
// rundi po slusaocu" i "pobednik iz glasova" bila izracunavanja nad listama,
// kako specifikacija trazi za domenski paket.
import 'ids.dart';

final class Vote {
  const Vote({
    required this.id,
    required this.roundId,
    required this.proposalId,
    required this.voterId,
    required this.castAt,
  });

  final VoteId id;
  final RoundId roundId;
  final ProposalId proposalId;
  final UserId voterId;
  final DateTime castAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vote &&
          other.id == id &&
          other.roundId == roundId &&
          other.proposalId == proposalId &&
          other.voterId == voterId &&
          other.castAt == castAt;

  @override
  int get hashCode =>
      Object.hash(id, roundId, proposalId, voterId, castAt);

  @override
  String toString() => 'Vote($voterId -> $proposalId)';
}
