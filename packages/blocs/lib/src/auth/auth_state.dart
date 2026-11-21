// Stanja prijave: pocetak / ucitavanje / prijavljen / odjavljen / greska.
//
// Stanja su jednaka po vrednosti (Equatable). Ekran prijave crta samo ova
// stanja; pravila i poruke ostaju u domenu i `serverMessage`-u.
import 'package:equatable/equatable.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Pre prvog dogadjaja. Cuvar ruta ga tretira kao odjavljenog (na prijavu).
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Prijava ili obnova sesije u toku.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Prijavljen korisnik — iz odgovora servera, nikad iz unosa klijenta.
final class Authenticated extends AuthState {
  const Authenticated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

/// Odjavljen (ili bez sacuvane sesije): cuvar ruta vodi na prijavu.
final class Unauthenticated extends AuthState {
  const Unauthenticated({this.expired = false});

  /// Prijava je istekla (server je odbio token sa `session_expired`, usred
  /// rada ili pri obnovi posle ponovnog pokretanja) — ekran prijave to kaze
  /// korisniku. Odjava i prvo pokretanje bez tokena su `false`.
  final bool expired;

  @override
  List<Object?> get props => [expired];
}

/// Prijava nije uspela. Bez teksta — poruku bira aplikacija (`serverMessage`
/// iz koda, ukljucujuci i `BackofficeNotAllowed` recima).
final class AuthFailure extends AuthState {
  const AuthFailure(this.reason);

  final ApiError reason;

  @override
  List<Object?> get props => [reason];
}
