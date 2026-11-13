// Podesavanja servera iz okruzenja (.env lokalno, `env_file` u Compose-u).
//
// Tajne (lozinka baze, kljuc spoljnog servisa) nikad nisu u kodu: stizu iz
// okruzenja, a razvojne vrednosti su u `.env.example`.
import 'dart:io';

final class Config {
  const Config({
    required this.port,
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUser,
    required this.dbPassword,
  });

  /// Cita podesavanja iz mape okruzenja; baca [ConfigException] sa spiskom
  /// svih promenljivih koje nedostaju (a ne samo prve).
  factory Config.fromEnvironment(Map<String, String> env) {
    final missing = <String>[];
    String need(String key) {
      final value = env[key];
      if (value == null || value.isEmpty) missing.add(key);
      return value ?? '';
    }

    int needInt(String key) {
      final raw = need(key);
      final value = int.tryParse(raw);
      if (value == null && raw.isNotEmpty) missing.add('$key (nije broj)');
      return value ?? 0;
    }

    final config = Config(
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      dbHost: need('DB_HOST'),
      dbPort: needInt('DB_PORT'),
      dbName: need('DB_NAME'),
      dbUser: need('DB_USER'),
      dbPassword: need('DB_PASSWORD'),
    );
    if (missing.isNotEmpty) throw ConfigException(missing);
    return config;
  }

  final int port;
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;
}

final class ConfigException implements Exception {
  const ConfigException(this.missing);

  final List<String> missing;

  @override
  String toString() =>
      'Nedostaju promenljive okruzenja: ${missing.join(', ')} '
      '(kopiraj .env.example u .env u korenu repozitorijuma)';
}

/// Cita `KEY=VALUE` redove iz .env fajla (prazni redovi i `#` komentari se
/// preskacu). Treba samo pri pokretanju van Docker-a; u Compose-u
/// promenljive vec stizu kroz `env_file`.
Map<String, String> readDotEnv(File file) {
  if (!file.existsSync()) return const {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    values[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim();
  }
  return values;
}
