// Soba — mesto gde se predlazu pesme i glasa.
//
// Minimalan model za KT1 (odluka O8): samo identifikator, naziv i host.
// Stanja sobe (otvorena/pauzirana/zatvorena) dolaze sa backoffice celinom.
import 'ids.dart';

final class Room {
  const Room({required this.id, required this.name, required this.hostId});

  final RoomId id;
  final String name;
  final UserId hostId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room &&
          other.id == id &&
          other.name == name &&
          other.hostId == hostId;

  @override
  int get hashCode => Object.hash(id, name, hostId);

  @override
  String toString() => 'Room($name)';
}
