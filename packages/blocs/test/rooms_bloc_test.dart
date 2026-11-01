// RoomsBloc: lista soba i pravljenje nove sobe (home tok).
//
// Po istom obrascu kao ostali Bloc-ovi: pravila se proveravaju domenom pre
// poziva porta; prekrsaj je `ruleError`, tehnicki neuspeh je `RoomsError`.
// Ime sobe ne sme biti prazno — to proverava domen kao tip greske, a tekst
// poruke bira aplikacija.
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

class _MockRepository extends Mock implements ProposalRepository {}

const _room = Room(id: RoomId('r1'), name: 'Petak', hostId: UserId('h1'));

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  RoomsBloc build() => RoomsBloc(
        repository: repository,
        hostId: const UserId('h1'),
      );

  group('ucitavanje', () {
    blocTest<RoomsBloc, RoomsState>(
      'lista soba',
      build: build,
      setUp: () => when(() => repository.loadRooms()).thenAnswer(
        (_) async => const [_room],
      ),
      act: (bloc) => bloc.add(const RoomsRequested()),
      expect: () => [
        isA<RoomsLoading>(),
        isA<RoomsLoaded>().having((s) => s.rooms.length, 'broj soba', 1),
      ],
    );

    blocTest<RoomsBloc, RoomsState>(
      'greska porta daje ekran greske',
      build: build,
      setUp: () =>
          when(() => repository.loadRooms()).thenThrow(Exception('pad')),
      act: (bloc) => bloc.add(const RoomsRequested()),
      expect: () => [isA<RoomsLoading>(), isA<RoomsError>()],
    );
  });

  group('pravljenje sobe', () {
    blocTest<RoomsBloc, RoomsState>(
      'nova soba se dodaje na kraj liste',
      build: build,
      seed: () => const RoomsLoaded(rooms: [_room]),
      setUp: () {
        when(
          () => repository.createRoom(
            name: any(named: 'name'),
            hostId: any(named: 'hostId'),
          ),
        ).thenAnswer(
          (_) async => const Room(
            id: RoomId('r9'),
            name: 'Nova',
            hostId: UserId('h1'),
          ),
        );
      },
      act: (bloc) => bloc.add(const RoomCreated('Nova')),
      expect: () => [
        isA<RoomsLoaded>().having((s) => s.rooms.length, 'broj soba', 2),
      ],
      verify: (_) {
        verify(
          () => repository.createRoom(name: 'Nova', hostId: const UserId('h1')),
        ).called(1);
      },
    );

    blocTest<RoomsBloc, RoomsState>(
      'prazan naziv: pravilo odbija, port se ne zove',
      build: build,
      seed: () => const RoomsLoaded(rooms: [_room]),
      act: (bloc) => bloc.add(const RoomCreated('   ')),
      expect: () => [
        isA<RoomsLoaded>().having(
          (s) => s.ruleError,
          'ruleError',
          isA<RoomNameEmpty>(),
        ),
      ],
      verify: (_) {
        verifyNever(
          () => repository.createRoom(
            name: any(named: 'name'),
            hostId: any(named: 'hostId'),
          ),
        );
      },
    );
  });
}
