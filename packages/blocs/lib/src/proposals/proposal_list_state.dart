// Stanja ekrana glavnog toka: ucitavanje / greska / prazno / podaci.
//
// Sealed da `switch` na ekranu mora obraditi svako stanje — zaboravljeno
// stanje je greska kompajliranja, ne bag na odbrani. Equatable: dva stanja
// sa istim podacima su jednaka, pa Bloc ne emituje duplikate.
import 'package:equatable/equatable.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import '../ports/room_snapshot.dart';

sealed class ProposalListState extends Equatable {
  const ProposalListState();

  @override
  List<Object?> get props => [];
}

/// Pre prvog dogadjaja. Ekran ga crta isto kao ucitavanje.
final class ProposalsInitial extends ProposalListState {
  const ProposalsInitial();
}

/// Port radi (ucitavanje sobe).
final class ProposalsLoading extends ProposalListState {
  const ProposalsLoading();
}

/// Soba bez ijednog predloga — nosi snimak da bi prvi predlog mogao da se doda.
final class ProposalsEmpty extends ProposalListState {
  const ProposalsEmpty(this.snapshot);

  final RoomSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

/// Podaci sobe.
///
/// [tally] racuna domen (`voteTally`), Bloc ga samo cuva. [ruleError] je
/// razlog zbog kog je poslednja akcija odbijena pravilom (port nije pozvan);
/// tekst poruke bira aplikacija po tipu greske. `ProposalRuleError` nema
/// `==`, pa se poredi po identitetu: isti prekrsaj dva puta zaredom daje
/// novo stanje i ekran ponovo prikazuje poruku.
final class ProposalsLoaded extends ProposalListState {
  const ProposalsLoaded({
    required this.snapshot,
    required this.tally,
    this.ruleError,
  });

  final RoomSnapshot snapshot;
  final Map<ProposalId, int> tally;
  final ProposalRuleError? ruleError;

  @override
  List<Object?> get props => [snapshot, tally, ruleError];
}

/// Tehnicka greska porta. Bez teksta (standard: poruku bira aplikacija) —
/// ekran nudi "Pokusaj ponovo", koji salje `ProposalsRequested`.
final class ProposalsError extends ProposalListState {
  const ProposalsError();
}
