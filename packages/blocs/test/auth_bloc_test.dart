// AuthBloc: prijava, obnova sesije, odjava i istek.
//
// Po istom obrascu kao ostali Bloc testovi: mock porta (mocktail),
// greska se nosi kao tip (`ServerRejected`), skladiste se proverava
// (`verify`), tehnicki kvar je genericki `Exception`.
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockTokenStore extends Mock implements TokenStore {}

const _user = User(
  id: UserId('u1'),
  displayName: 'Ana',
  role: Role.listener,
);

AuthSession _session() => AuthSession(
  user: _user,
  token: 'tok123',
  expiresAt: DateTime.utc(2027),
);

ServerRejected _rejected(String code) =>
    ServerRejected(ApiError(code: code, data: const {}));

void main() {
  setUpAll(() => registerFallbackValue(AppTarget.mobile));

  late _MockAuthRepository repository;
  late _MockTokenStore store;

  setUp(() {
    repository = _MockAuthRepository();
    store = _MockTokenStore();
    when(() => store.readToken()).thenAnswer((_) async => null);
    when(
      () => store.writeToken(any()),
    ).thenAnswer((_) async {});
    when(() => store.deleteToken()).thenAnswer((_) async {});
    when(() => repository.logout()).thenAnswer((_) async {});
  });

  AuthBloc build() =>
      AuthBloc(repository: repository, tokenStore: store);

  group('prijava', () {
    blocTest<AuthBloc, AuthState>(
      'uspeh cuva token i daje korisnika',
      build: build,
      setUp: () {
        when(
          () => repository.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
            app: any(named: 'app'),
          ),
        ).thenAnswer((_) async => _session());
      },
      act: (bloc) => bloc.add(
        const LoginRequested(
          username: 'ana',
          password: 'demo1234',
          app: AppTarget.mobile,
        ),
      ),
      expect: () => [const AuthLoading(), const Authenticated(_user)],
      verify: (_) {
        verify(() => store.writeToken('tok123')).called(1);
        verifyNever(() => store.deleteToken());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'pogresna lozinka je greska bez odjave',
      build: build,
      setUp: () {
        when(
          () => repository.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
            app: any(named: 'app'),
          ),
        ).thenThrow(_rejected(ErrorCodes.invalidCredentials));
      },
      act: (bloc) => bloc.add(
        const LoginRequested(
          username: 'ana',
          password: 'lose',
          app: AppTarget.mobile,
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(ApiError(code: ErrorCodes.invalidCredentials)),
      ],
      verify: (_) {
        verifyNever(() => store.writeToken(any()));
        verifyNever(() => store.deleteToken());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'zabranjena aplikacija nosi razlog recima',
      build: build,
      setUp: () {
        when(
          () => repository.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
            app: any(named: 'app'),
          ),
        ).thenThrow(
          _rejected(ErrorCodes.backofficeNotAllowed),
        );
      },
      act: (bloc) => bloc.add(
        const LoginRequested(
          username: 'ana',
          password: 'demo1234',
          app: AppTarget.backoffice,
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(ApiError(code: ErrorCodes.backofficeNotAllowed)),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'tehnicki kvar je greska sa nepoznatim kodom',
      build: build,
      setUp: () {
        when(
          () => repository.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
            app: any(named: 'app'),
          ),
        ).thenThrow(Exception('nema mreze'));
      },
      act: (bloc) => bloc.add(
        const LoginRequested(
          username: 'ana',
          password: 'demo1234',
          app: AppTarget.mobile,
        ),
      ),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(ApiError(code: ErrorCodes.unknown)),
      ],
    );
  });

  group('obnova sesije', () {
    blocTest<AuthBloc, AuthState>(
      'sacuvani token daje prijavljenog',
      build: build,
      setUp: () {
        when(() => store.readToken()).thenAnswer((_) async => 'tok123');
        when(
          () => repository.me(any()),
        ).thenAnswer((_) async => _user);
      },
      act: (bloc) => bloc.add(const SessionRestored()),
      expect: () => [const AuthLoading(), const Authenticated(_user)],
      verify: (_) {
        verify(() => repository.me('tok123')).called(1);
        verifyNever(() => store.deleteToken());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'bez tokena vodi na prijavu bez poziva serveru',
      build: build,
      act: (bloc) => bloc.add(const SessionRestored()),
      expect: () => [const AuthLoading(), const Unauthenticated()],
      verify: (_) => verifyNever(() => repository.me(any())),
    );

    blocTest<AuthBloc, AuthState>(
      'istekla sacuvana sesija brise token, vodi na prijavu i kaze zasto',
      build: build,
      setUp: () {
        when(() => store.readToken()).thenAnswer((_) async => 'mrtav');
        when(
          () => repository.me(any()),
        ).thenThrow(_rejected(ErrorCodes.sessionExpired));
      },
      act: (bloc) => bloc.add(const SessionRestored()),
      expect: () => [
        const AuthLoading(),
        const Unauthenticated(expired: true),
      ],
      verify: (_) => verify(() => store.deleteToken()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'blokiran nalog pri obnovi nosi razlog',
      build: build,
      setUp: () {
        when(() => store.readToken()).thenAnswer((_) async => 'tok123');
        when(
          () => repository.me(any()),
        ).thenThrow(_rejected(ErrorCodes.userBlocked));
      },
      act: (bloc) => bloc.add(const SessionRestored()),
      expect: () => [
        const AuthLoading(),
        const AuthFailure(ApiError(code: ErrorCodes.userBlocked)),
      ],
      verify: (_) => verifyNever(() => store.deleteToken()),
    );
  });

  group('odjava i istek', () {
    blocTest<AuthBloc, AuthState>(
      'odjava brise prijavu i token',
      build: build,
      seed: () => const Authenticated(_user),
      act: (bloc) => bloc.add(const LogoutRequested()),
      expect: () => [const Unauthenticated()],
      verify: (_) {
        verify(() => repository.logout()).called(1);
        verify(() => store.deleteToken()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'odjava uspeva i kad server odbije poziv',
      build: build,
      setUp: () {
        when(
          () => repository.logout(),
        ).thenThrow(_rejected(ErrorCodes.sessionExpired));
      },
      seed: () => const Authenticated(_user),
      act: (bloc) => bloc.add(const LogoutRequested()),
      expect: () => [const Unauthenticated()],
      verify: (_) => verify(() => store.deleteToken()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'istek usred rada brise token, vodi na prijavu i kaze zasto',
      build: build,
      seed: () => const Authenticated(_user),
      act: (bloc) => bloc.add(const SessionExpired()),
      expect: () => [const Unauthenticated(expired: true)],
      verify: (_) {
        verify(() => store.deleteToken()).called(1);
        verifyNever(() => repository.logout());
      },
    );
  });

  group('jednakost stanja', () {
    test('isti korisnik je isto stanje', () {
      expect(const Authenticated(_user), const Authenticated(_user));
      expect(
        const AuthFailure(ApiError(code: ErrorCodes.sessionExpired)),
        const AuthFailure(ApiError(code: ErrorCodes.sessionExpired)),
      );
      expect(const Unauthenticated(), const Unauthenticated());
      // Istekla prijava i odjava nisu isto stanje (ekran prijave ih razlikuje).
      expect(const Unauthenticated(expired: true), isNot(const Unauthenticated()));
    });
  });
}
