// Dogadjaji home toka: ucitavanje soba i pravljenje nove sobe.
import 'package:equatable/equatable.dart';

sealed class RoomsEvent extends Equatable {
  const RoomsEvent();

  @override
  List<Object?> get props => [];
}

/// Ucitaj sobe — i prvo ucitavanje i "Pokusaj ponovo".
final class RoomsRequested extends RoomsEvent {
  const RoomsRequested();
}

/// Napravi novu sobu sa zadatim nazivom.
final class RoomCreated extends RoomsEvent {
  const RoomCreated(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}
