// Povezivanje sa bazom: pool konekcija i cekanje da baza postane dostupna.
import 'dart:io';

import 'package:postgres/postgres.dart';

import '../config.dart';

/// Otvara pool i ceka da baza odgovori. Compose vec ceka zdravu bazu, ali
/// pri pokretanju van Docker-a baza moze tek da se podize — zato nekoliko
/// pokusaja, pa jasna greska umesto beskonacnog cekanja.
Future<Pool<void>> openDatabase(
  Config config, {
  int attempts = 10,
  Duration pause = const Duration(seconds: 1),
}) async {
  final pool = Pool<void>.withEndpoints(
    [
      Endpoint(
        host: config.dbHost,
        port: config.dbPort,
        database: config.dbName,
        username: config.dbUser,
        password: config.dbPassword,
      ),
    ],
    settings: const PoolSettings(
      maxConnectionCount: 10,
      // Lokalna baza u Docker-u nema TLS.
      sslMode: SslMode.disable,
    ),
  );

  for (var attempt = 1; ; attempt++) {
    try {
      await pool.execute('SELECT 1');
      return pool;
    } on Object catch (error) {
      if (attempt >= attempts) {
        await pool.close();
        rethrow;
      }
      stderr.writeln(
        'Baza nije dostupna (pokusaj $attempt/$attempts): $error',
      );
      await Future<void>.delayed(pause);
    }
  }
}
