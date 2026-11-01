// Soba — mesto gde se predlazu pesme i glasa.
//
// Stanja sobe (`RoomStatus`) stigla su sa backoffice celinom: predlozi nose
// muzicki tok, soba nosi zivotni ciklus (otvorena/pauzirana/zatvorena).
import 'ids.dart';
import 'room_status.dart';

final class Room {
  const Room({
    required this.id,
    required this.name,
    required this.hostId,
    this.status = const RoomOpen(),
  });

  final RoomId id;
  final String name;
  final UserId hostId;
  final RoomStatus status;

  /// Nova soba sa promenjenim statusom. Validnost prelaza proverava
  /// `canTransitionRoom` — ova metoda samo pravi kopiju.
  Room withStatus(RoomStatus next) =>
      Room(id: id, name: name, hostId: hostId, status: next);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room &&
          other.id == id &&
          other.name == name &&
          other.hostId == hostId &&
          other.status.runtimeType == status.runtimeType;

  @override
  int get hashCode => Object.hash(id, name, hostId, status.runtimeType);

  @override
  String toString() => 'Room($name)';
}
