// Stanja moderatorskog ekrana: ucitavanje / greska / podaci.
//
// Sealed da `switch` na ekranu mora obraditi svako stanje. Equatable: dva
// stanja sa istim podacima su jednaka, pa Bloc ne emituje duplikate.
// Prazan prikaz nije posebno stanje: prazne liste u `ModerationLoaded`
// ekran crta kao "nema soba/predloga".
import 'package:equatable/equatable.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import '../ports/room_snapshot.dart';

sealed class ModerationState extends Equatable {
  const ModerationState();

  @override
  List<Object?> get props => [];
}

/// Pre prvog dogadjaja. Ekran ga crta isto kao ucitavanje.
final class ModerationInitial extends ModerationState {
  const ModerationInitial();
}

/// Port radi (lista soba ili snimak sobe).
final class ModerationLoading extends ModerationState {
  const ModerationLoading();
}

/// Podaci: lista soba + izabrana soba (null dok se ne izabere).
///
/// [tally] racuna domen (`voteTally`), Bloc ga samo cuva. [ruleError] je
/// razlog zbog kog je poslednja akcija odbijena pravilom (port nije pozvan);
/// tekst poruke bira aplikacija po tipu greske.
final class ModerationLoaded extends ModerationState {
  const ModerationLoaded({
    required this.rooms,
    this.snapshot,
    this.tally = const {},
    this.ruleError,
  });

  final List<Room> rooms;

  /// Snimak izabrane sobe; null dok moderator ne izabere sobu.
  final RoomSnapshot? snapshot;
  final Map<ProposalId, int> tally;
  final ProposalRuleError? ruleError;

  /// Kopija sa zamenjenim prekrsajem pravila; port nije pozvan pa se
  /// podaci ne menjaju — samo razlog odbijanja akcije.
  ModerationLoaded copyWith({ProposalRuleError? ruleError}) =>
      ModerationLoaded(
        rooms: rooms,
        snapshot: snapshot,
        tally: tally,
        ruleError: ruleError,
      );

  @override
  List<Object?> get props => [rooms, snapshot, tally, ruleError];
}

/// Tehnicka greska porta. Bez teksta — ekran nudi "Pokusaj ponovo".
final class ModerationError extends ModerationState {
  const ModerationError();
}
