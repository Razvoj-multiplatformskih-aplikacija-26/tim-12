// Prelazi stanja: svih 7 dozvoljenih + kljucne zabrane.
//
// Zasto bas ovi: `canTransition` je jedina kapija promene stanja — ako neko
// na odbrani doda/smeni prelaz, ovaj test je prvi koji to uhvati.
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

void main() {
  group('canTransition', () {
    test('svih 7 dozvoljenih prelaza', () {
      final allowed = [
        (const Proposed(), const InVoting()),
        (const Proposed(), const Removed()),
        (const InVoting(), const Winner()),
        (const InVoting(), const Rejected()),
        (const InVoting(), const Removed()),
        (const Winner(), const Removed()),
        (const Winner(), Played(DateTime.utc(2026, 10, 1, 21))),
      ];
      for (final (from, to) in allowed) {
        expect(canTransition(from, to), isTrue);
      }
    });

    test('zabrane: preskakanje stepenika i izlaz iz terminalnih', () {
      final forbidden = [
        // Preskoci: pravo u pobednika/odbijenu bez glasanja.
        (const Proposed(), const Winner()),
        (const Proposed(), const Rejected()),
        (const Proposed(), Played(DateTime.utc(2026, 10, 1, 21))),
        (const InVoting(), Played(DateTime.utc(2026, 10, 1, 21))),
        // Terminalna stanja nemaju izlaz.
        (Played(DateTime.utc(2026, 10, 1, 21)), const Removed()),
        (const Rejected(), const Removed()),
        (const Removed(), const Proposed()),
      ];
      for (final (from, to) in forbidden) {
        expect(canTransition(from, to), isFalse);
      }
    });
  });
}
