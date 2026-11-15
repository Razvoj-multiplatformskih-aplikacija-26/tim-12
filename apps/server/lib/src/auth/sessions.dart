// Prijave (sesije) koje izdaje server.
//
// Token je 32 slucajna bajta (base64url) — zna ga samo klijent. Baza cuva
// samo SHA-256 hes tokena: ko procita bazu, ne moze da se predstavi kao
// korisnik. Odbaceno: JWT — potpisan token se ne moze opozvati pre isteka,
// a odjava ovde je brisanje reda.
//
// "Sad" stize kroz [clock], pa testovi proveravaju istek bez cekanja.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'users.dart';

/// Ishod trazenja prijave po tokenu.
sealed class SessionLookup {
  const SessionLookup();
}

/// Prijava vazi; [user] je korisnik koga je server prijavio.
final class ActiveSession extends SessionLookup {
  const ActiveSession(this.user, this.expiresAt);

  final User user;
  final DateTime expiresAt;
}

/// Prijava je postojala, ali je istekla (klijent to kaze korisniku).
final class ExpiredSession extends SessionLookup {
  const ExpiredSession();
}

/// Token ne postoji (nikad izdat, ili odjavljen).
final class UnknownSession extends SessionLookup {
  const UnknownSession();
}

final class SessionStore {
  SessionStore(this._db, {required this.ttl, required this.clock});

  final Session _db;

  /// Trajanje prijave iz podesavanja servera (`SESSION_TTL_MINUTES`).
  final Duration ttl;
  final DateTime Function() clock;

  final _random = Random.secure();

  /// Izdaje novu prijavu i vraca token (jedini put kad token napusta server).
  Future<(String token, DateTime expiresAt)> create(UserId userId) async {
    final token = base64Url
        .encode(List.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    final expiresAt = clock().toUtc().add(ttl);
    await _db.execute(
      Sql.named(
        'INSERT INTO sessions (token_hash, user_id, expires_at) '
        'VALUES (@hash, @user, @expires)',
      ),
      parameters: {
        'hash': _hash(token),
        'user': userId.value,
        'expires': expiresAt,
      },
    );
    return (token, expiresAt);
  }

  /// Trazi prijavu po tokenu. Istekla prijava se usput brise.
  Future<SessionLookup> lookup(String token) async {
    final rows = await _db.execute(
      Sql.named(
        'SELECT s.expires_at, $userColumns FROM sessions s '
        'JOIN users u ON u.id = s.user_id WHERE s.token_hash = @hash',
      ),
      parameters: {'hash': _hash(token)},
    );
    if (rows.isEmpty) return const UnknownSession();
    final row = rows.single;
    final expiresAt = row[0]! as DateTime;
    if (!clock().isBefore(expiresAt)) {
      await delete(token);
      return const ExpiredSession();
    }
    return ActiveSession(userFromRow(row, 1), expiresAt);
  }

  /// Odjava: brise prijavu (posle toga token je nepoznat).
  Future<void> delete(String token) => _db.execute(
    Sql.named('DELETE FROM sessions WHERE token_hash = @hash'),
    parameters: {'hash': _hash(token)},
  );

  static String _hash(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}
