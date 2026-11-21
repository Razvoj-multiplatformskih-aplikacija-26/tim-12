// Stanja home ekrana: ucitavanje / greska / podaci.
//
// Prazan prikaz nije posebno stanje: praznu listu u `RoomsLoaded` ekran
// crta kao "nema soba — napravi prvu".
import 'package:equatable/equatable.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

sealed class RoomsState extends Equatable {
  const RoomsState();

  @override
  List<Object?> get props => [];
}

/// Pre prvog dogadjaja. Ekran ga crta isto kao ucitavanje.
final class RoomsInitial extends RoomsState {
  const RoomsInitial();
}

/// Port radi (lista soba).
final class RoomsLoading extends RoomsState {
  const RoomsLoading();
}

/// Lista soba. [ruleError] je razlog zbog kog pravljenje sobe nije proslo
/// (port nije pozvan); tekst poruke bira aplikacija po tipu greske.
final class RoomsLoaded extends RoomsState {
  const RoomsLoaded({required this.rooms, this.ruleError});

  final List<Room> rooms;
  final ProposalRuleError? ruleError;

  @override
  List<Object?> get props => [rooms, ruleError];
}

/// Greska porta. Bez teksta — ekran nudi "Pokusaj ponovo".
///
/// [reason] je serverski razlog odbijanja (`{code, data}` iz ugovora),
/// ili null kad je greska tehnicka. Posle odbijanja Bloc sam osvezava
/// listu soba; poruku bira aplikacija (`serverMessage`).
final class RoomsError extends RoomsState {
  const RoomsError({this.reason});

  final ApiError? reason;

  @override
  List<Object?> get props => [reason];
}
