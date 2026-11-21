// DTO prijave i sesije — oblik tela za `/auth/login`, `/auth/me` i odgovor
// na uspesnu prijavu (vidi `apps/server` README).
//
// Klijent nikad ne salje `userId` kao identitet: server zna ko poziva samo
// iz tokena. DTO zato nosi samo kredencijale i ciljanu aplikaciju.
import 'package:radioroom_domain/radioroom_domain.dart';

/// Ciljana aplikacija pri prijavi. Server po njoj bira domensko pravilo
/// (`checkCanUseMobile` / `checkCanUseBackoffice`) i isti kôd greske.
enum AppTarget { mobile, backoffice }

/// Telo `POST /auth/login`: `{username, password, app}`.
final class LoginRequest {
  const LoginRequest({
    required this.username,
    required this.password,
    this.app = AppTarget.mobile,
  });

  final String username;
  final String password;
  final AppTarget app;

  Map<String, Object?> toJson() => {
    'username': username,
    'password': password,
    'app': app.name,
  };
}

/// Korisnik iz odgovora servera. Oblik je isti kao `userJson` na serveru:
/// `{id, displayName, role}` — `blocked` server ne salje (blokiran nalog
/// dobija `user_blocked` gresku umesto korisnika), pa je ovde opciono i
/// podrazumevano `false` za slucaj da ga novija verzija servera posalje.
final class UserDto {
  const UserDto({
    required this.id,
    required this.displayName,
    required this.role,
    this.blocked = false,
  });

  final UserId id;
  final String displayName;
  final Role role;
  final bool blocked;

  factory UserDto.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final displayName = json['displayName'];
    final role = Role.values.asNameMap()[json['role']];
    if (id is! String || id.isEmpty) {
      throw const FormatException('UserDto.id mora biti neprazan string');
    }
    if (displayName is! String) {
      throw const FormatException('UserDto.displayName mora biti string');
    }
    if (role == null) {
      throw FormatException('UserDto.role nepoznat: ${json['role']}');
    }
    final blocked = json['blocked'];
    return UserDto(
      id: UserId(id),
      displayName: displayName,
      role: role,
      blocked: blocked is bool ? blocked : false,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.value,
    'displayName': displayName,
    'role': role.name,
  };

  User toDomain() =>
      User(id: id, displayName: displayName, role: role, blocked: blocked);

  factory UserDto.fromDomain(User user) => UserDto(
    id: user.id,
    displayName: user.displayName,
    role: user.role,
    blocked: user.blocked,
  );
}

/// Odgovor na uspesnu prijavu: `{token, expiresAt, user}`.
/// Klijent token cuva u bezbednom skladistu platforme, lozinku nikad.
final class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  final String token;
  final DateTime expiresAt;
  final UserDto user;

  factory LoginResponse.fromJson(Map<String, Object?> json) {
    final token = json['token'];
    final expiresAt = DateTime.tryParse('${json['expiresAt']}');
    final user = json['user'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('LoginResponse.token mora postojati');
    }
    if (expiresAt == null) {
      throw FormatException(
        'LoginResponse.expiresAt nije datum: ${json['expiresAt']}',
      );
    }
    if (user is! Map<String, Object?>) {
      throw const FormatException('LoginResponse.user mora biti objekat');
    }
    return LoginResponse(
      token: token,
      expiresAt: expiresAt,
      user: UserDto.fromJson(user),
    );
  }
}
