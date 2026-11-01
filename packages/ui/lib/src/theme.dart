// Tema aplikacija RadioRoom (odluka o UI stilu, 31. 10. 2026).
//
// Material 3, seed boja #5B3FD9, svetla i tamna varijanta (aplikacija bira
// `ThemeMode.system`), font Inter iz ovog paketa. Radijusi 12 (kartice),
// 8 (cipovi), 16 (dijalozi); razmaci u [Spacing]. Brojevi (glasovi, vreme)
// koriste [tabularFigures] da se kolone ne "pomeraju" pri promeni cifara.
import 'package:flutter/material.dart';

/// Seed boja brenda.
const brandSeed = Color(0xFF5B3FD9);

/// Font iz ovog paketa — iz drugog paketa se adresira sa `packages/` prefiksom.
const _fontFamily = 'packages/radioroom_ui/Inter';

/// Tema za datu svetlinu (svetla / tamna).
ThemeData radioRoomTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandSeed,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: _fontFamily,
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Razmaci (4/8/12/16/24/32) — jedini dozvoljeni razmaci u rasporedu.
abstract final class Spacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Stil za brojeve: cifre iste sirine.
const tabularFigures = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);
