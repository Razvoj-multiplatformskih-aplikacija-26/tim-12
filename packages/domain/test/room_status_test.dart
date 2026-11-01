// Prelazi stanja sobe: dozvoljeni + kljucne zabrane.
//
// Zasto: `canTransitionRoom` je jedina kapija promene stanja sobe —
// moderator (zatvaranje) i KT2 server je pitaju, pa test hvata svaku
// neplaniranu izmenu prelaza.
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

void main() {
  group('canTransitionRoom', () {
    test('dozvoljeni prelazi', () {
      final allowed = [
        (const RoomOpen(), const RoomPaused()),
        (const RoomPaused(), const RoomOpen()),
        (const RoomOpen(), const RoomClosed()),
        (const RoomPaused(), const RoomClosed()),
      ];
      for (final (from, to) in allowed) {
        expect(canTransitionRoom(from, to), isTrue);
      }
    });

    test('zabrane: izlaz iz zatvorene i prelaz u isto', () {
      final forbidden = [
        (const RoomClosed(), const RoomOpen()),
        (const RoomClosed(), const RoomPaused()),
        (const RoomOpen(), const RoomOpen()),
        (const RoomClosed(), const RoomClosed()),
      ];
      for (final (from, to) in forbidden) {
        expect(canTransitionRoom(from, to), isFalse);
      }
    });
  });

  group('Room.status', () {
    test('podrazumevano otvorena', () {
      const room = Room(
        id: RoomId('r1'),
        name: 'Petak',
        hostId: UserId('h1'),
      );
      expect(room.status, const RoomOpen());
    });
  });
}
