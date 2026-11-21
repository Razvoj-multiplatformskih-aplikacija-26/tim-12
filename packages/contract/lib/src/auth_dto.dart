// DTO prijave i sesije — oblik tela za `/auth/login`, `/auth/me` i odgovor
// na uspesnu prijavu (vidi `apps/server` README).
//
// Klijent nikad ne salje `userId` kao identitet: server zna ko poziva samo
// iz tokena. DTO zato nosi samo kredencijale i ciljanu aplikaciju.
import 'wire_codes.dart';

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

  /// `app` je podrazumevano `mobile`. Baca [FormatException] kad nedostaju
  /// kredencijali ili je aplikacija nepoznata.
  factory LoginRequest.fromJson(Map<String, Object?> json) {
    final username = json['username'];
    final password = json['password'];
    final app = AppTarget.values.asNameMap()[json['app'] ?? 'mobile'];
    if (username is! String || password is! String || app == null) {
      throw const FormatException('LoginRequest trazi username/password/app');
    }
    return LoginRequest(username: username, password: password, app: app);
  }

  Map<String, Object?> toJson() => {
    'username': username,
    'password': password,
    'app': app.name,
  };
}

/// Korisnik iz odgovora servera: `{id, displayName, role}` — `blocked`
/// server ne salje (blokiran nalog dobija `user_blocked` gresku umesto
/// korisnika), pa je ovde opciono i podrazumevano `false` za slucaj da ga
/// novija verzija servera posalje.
final class UserDto {
  const UserDto({
    required this.id,
    required this.displayName,
    required this.role,
    this.blocked = false,
  });

  final String id;
  final String displayName;

  /// Jedan od [RoleCodes].
  final String role;
  final bool blocked;

  factory UserDto.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final displayName = json['displayName'];
    final role = json['role'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('UserDto.id mora biti neprazan string');
    }
    if (displayName is! String) {
      throw const FormatException('UserDto.displayName mora biti string');
    }
    if (role is! String || !RoleCodes.all.contains(role)) {
      throw FormatException('UserDto.role nepoznat: $role');
    }
    final blocked = json['blocked'];
    return UserDto(
      id: id,
      displayName: displayName,
      role: role,
      blocked: blocked is bool ? blocked : false,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'role': role,
  };
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

  Map<String, Object?> toJson() => {
    'token': token,
    'expiresAt': wireTime(expiresAt),
    'user': user.toJson(),
  };
}
