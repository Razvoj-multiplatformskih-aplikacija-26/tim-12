// Dijalog sa pregledom precica na tastaturi (taster `?`).
//
// Izdvojen da ekran ostane citljiv: ovde su samo tekstovi precica, nikakva
// logika ekrana. Otvara se i dugmetom u AppBar-u (tooltip "Prečice (?)"),
// da se nadje i bez tastature.
import 'package:flutter/material.dart';

/// Jedna precica: koje dirke i sta rade.
class ShortcutHelpEntry {
  const ShortcutHelpEntry(this.keys, this.description);

  final String keys;
  final String description;
}

/// Sve precice ekrana moderacije, na jednom mestu (isti redosled kao
/// komentar na vrhu `moderation_screen.dart`).
const shortcutHelpEntries = [
  ShortcutHelpEntry('↑ ↓', 'Kretanje kroz predloge'),
  ShortcutHelpEntry('Delete', 'Ukloni izabrani predlog (na Mac-u i Backspace)'),
  ShortcutHelpEntry('Esc', 'Poništi izbor (ili nazad na sobe)'),
  ShortcutHelpEntry('R', 'Osveži prikaz'),
  ShortcutHelpEntry('?', 'Ovaj pregled prečica'),
];

/// Prikazuje dijalog sa pregledom precica.
Future<void> showShortcutsHelp(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prečice na tastaturi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in shortcutHelpEntries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        entry.keys,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: Text(entry.description)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
