// Dogadjaji prijave: prijava, odjava, obnova sacuvane sesije i istek.
//
// Bloc je Bloc sa dogadjajima (ne Cubit) — ekrani samo salju dogadjaje i
// crtaju stanje.
import 'package:equatable/equatable.dart';
import 'package:radioroom_contract/radioroom_contract.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Prijava korisnickim imenom i lozinkom u zadatu aplikaciju.
final class LoginRequested extends AuthEvent {
  const LoginRequested({
    required this.username,
    required this.password,
    required this.app,
  });

  final String username;
  final String password;

  /// Ciljana aplikacija: server po njoj bira domensko pravilo
  /// (`checkCanUseMobile` / `checkCanUseBackoffice`) i isti kôd greske.
  final AppTarget app;

  @override
  List<Object?> get props => [username, password, app];
}

/// Odjava: brise prijavu na serveru (best-effort) i token u skladistu.
final class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// Obnova sacuvane sesije pri pokretanju (`GET /auth/me` sacuvanim tokenom).
final class SessionRestored extends AuthEvent {
  const SessionRestored();
}

/// Istek sesije usred rada (401 sa data rute): brise token, vraca na
/// prijavu. Interno — salje ga mesto sastavljanja kroz `onAuthFailure`
/// HTTP klijenta, ne ekran.
final class SessionExpired extends AuthEvent {
  const SessionExpired();
}
