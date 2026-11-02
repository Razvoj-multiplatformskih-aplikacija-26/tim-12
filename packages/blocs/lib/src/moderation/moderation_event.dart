// Dogadjaji moderatorskog toka: ucitavanje liste/sobe i akcije osoblja.
//
// Ekran samo salje ove dogadjaje; sta oni znace (pravila, port) odlucuje
// Bloc pozivom domena. Sealed da Bloc mora obraditi svaki dogadjaj.
import 'package:equatable/equatable.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

sealed class ModerationEvent extends Equatable {
  const ModerationEvent();

  @override
  List<Object?> get props => [];
}

/// Ucitaj listu soba — i prvo ucitavanje i "Pokusaj ponovo".
final class ModerationStarted extends ModerationEvent {
  const ModerationStarted();
}

/// Otvori sobu: ucitaj njen snimak (predlozi, glasovi).
final class ModerationRoomOpened extends ModerationEvent {
  const ModerationRoomOpened(this.roomId);

  final RoomId roomId;

  @override
  List<Object?> get props => [roomId];
}

/// Moderator uklanja predlog (prelaz u `Removed`).
final class ModerationProposalRemoved extends ModerationEvent {
  const ModerationProposalRemoved(this.proposalId);

  final ProposalId proposalId;

  @override
  List<Object?> get props => [proposalId];
}

/// Moderator zatvara sobu (prelaz u `RoomClosed`).
final class ModerationRoomClosed extends ModerationEvent {
  const ModerationRoomClosed(this.roomId);

  final RoomId roomId;

  @override
  List<Object?> get props => [roomId];
}
