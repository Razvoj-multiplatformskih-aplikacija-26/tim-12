// Dogadjaji glavnog toka slusaoca (odluka O3: ucitavanje, predlog, glas;
// KT2: povlacenje svog predloga).
//
// Ekran samo salje ove dogadjaje; sta oni znace (pravila, port) odlucuje
// Bloc pozivom domena. Sealed da Bloc mora obraditi svaki dogadjaj.
import 'package:equatable/equatable.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

sealed class ProposalListEvent extends Equatable {
  const ProposalListEvent();

  @override
  List<Object?> get props => [];
}

/// Ucitaj sobu — i prvo ucitavanje i "Pokusaj ponovo".
final class ProposalsRequested extends ProposalListEvent {
  const ProposalsRequested();
}

/// Slusalac predlaze pesmu.
final class ProposalAdded extends ProposalListEvent {
  const ProposalAdded(this.song);

  final Song song;

  @override
  List<Object?> get props => [song];
}

/// Slusalac glasa za predlog.
final class VoteCast extends ProposalListEvent {
  const VoteCast(this.proposalId);

  final ProposalId proposalId;

  @override
  List<Object?> get props => [proposalId];
}

/// Slusalac povlaci svoj predlog dok ceka ishod.
final class ProposalWithdrawn extends ProposalListEvent {
  const ProposalWithdrawn(this.proposalId);

  final ProposalId proposalId;

  @override
  List<Object?> get props => [proposalId];
}
