// Ugovor je cist Dart: ne uvozi domenski paket, Flutter ni `dart:io`
// (zahtev KT2, stavka 2). Ovaj test pada ako neko vrati takvu zavisnost.
import 'dart:io';

import 'package:test/test.dart';

const _forbidden = ['radioroom_domain', 'package:flutter', 'dart:io'];

void main() {
  test('pubspec nema zavisnosti (domen, Flutter)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      isNot(contains(RegExp(r'^dependencies:', multiLine: true))),
    );
    expect(pubspec, isNot(contains('radioroom_domain')));
    expect(pubspec, isNot(contains('sdk: flutter')));
  });

  test('lib ne uvozi domen, Flutter ni dart:io', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in sources) {
      final imports = file.readAsLinesSync().where(
        (line) => line.startsWith('import ') || line.startsWith('export '),
      );
      for (final line in imports) {
        for (final forbidden in _forbidden) {
          expect(line, isNot(contains(forbidden)), reason: file.path);
        }
      }
    }
  });
}
