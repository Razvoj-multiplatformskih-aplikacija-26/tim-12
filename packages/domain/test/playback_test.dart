// currentPlaying: projekcija "sta ide sad" za view mod.
//
// Granicni slucajevi: dve pustene (kasnija je trenutna), nista pusteno,
// vreme pustanja u buducnosti (ignorise se).
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

const _room = RoomId('r1');
const _song = Song(title: 'Fuego', artist: 'Elena');

Proposal _played(String id, DateTime at) => Proposal(
  id: ProposalId(id),
  roomId: _room,
  song: _song,
  proposedBy: const UserId('u1'),
  proposedAt: DateTime.utc(2026, 10, 1, 19),
  status: Played(at),
);

void main() {
  final now = DateTime.utc(2026, 10, 1, 21);

  test('poslednja pustena je trenutna', () {
    final earlier = _played('a', DateTime.utc(2026, 10, 1, 20));
    final later = _played('b', DateTime.utc(2026, 10, 1, 20, 30));
    expect(
      currentPlaying(proposals: [earlier, later], now: now),
      same(later),
    );
  });

  test('nista pusteno ili sve u buducnosti: null', () {
    expect(currentPlaying(proposals: [], now: now), isNull);
    expect(
      currentPlaying(
        proposals: [_played('a', now.add(const Duration(minutes: 1)))],
        now: now,
      ),
      isNull,
    );
  });
}
