// Runda glasanja — vremenski prozor u kome se glasa (odluka O9).
//
// Minimalan entitet: identifikator, soba kojoj pripada, pocetak i kraj.
// Pravila ("jedan glas po rundi", "kasni glas") čitaju ovaj prozor;
// zato se trenuci porede kao parametri, a ne citanjem sistemskog sata.
import 'ids.dart';

final class Round {
  const Round({
    required this.id,
    required this.roomId,
    required this.startsAt,
    required this.endsAt,
  });

  final RoundId id;
  final RoomId roomId;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Glas koji stigne posle kraja runde se odbacuje (server-pravilo u KT2,
  /// ovde izracunavanje nad listama).
  bool isLate(DateTime castAt) => castAt.isAfter(endsAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Round &&
          other.id == id &&
          other.roomId == roomId &&
          other.startsAt == startsAt &&
          other.endsAt == endsAt;

  @override
  int get hashCode => Object.hash(id, roomId, startsAt, endsAt);

  @override
  String toString() => 'Round($id)';
}
