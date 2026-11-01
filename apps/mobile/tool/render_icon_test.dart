// Crtanje ikonice aplikacije (KT1 §1: ikonica). Ikonica je kod: boja i
// oblik menjaju se ovde, pa se slike ponovo prave.
//
// Nije u `test/`, pa ne ide sa obicnim testovima. Pokretanje iz apps/mobile:
//
//   flutter test tool/render_icon_test.dart   # pravi assets/icon/*.png
//   dart run flutter_launcher_icons           # pravi ikonice za platforme
//
// Motiv: bela "play" strelica (muzika) i dva talasa (radio, emitovanje).
// `icon.png` je cela ikonica (iOS, veb, stari Android); `icon_foreground.png`
// je samo motiv na providnoj pozadini za Android adaptivnu ikonicu — launcher
// je sece u krug ili drugi oblik, pa motiv mora stati u centralnih 66%.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

const _size = 1024.0;

/// Svetlija i tamnija nijansa boje brenda za blagi prelaz pozadine.
const _light = Color(0xFF7B61F0);
const _dark = Color(0xFF4529C4);

void main() {
  testWidgets('crta ikonicu aplikacije', (tester) async {
    await tester.runAsync(() async {
      // Cela ikonica: motif u krugu poluprecnika ~35% sirine.
      await _save('assets/icon/icon.png', background: true, radius: 360);
      // Adaptivna: bezbedna zona je krug 66/108 sirine (r ≈ 313 px).
      await _save(
        'assets/icon/icon_foreground.png',
        background: false,
        radius: 280,
      );
    });
  });
}

Future<void> _save(
  String path, {
  required bool background,
  required double radius,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  if (background) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_light, brandSeed, _dark],
        ).createShader(rect),
    );
  }
  _paintMotif(canvas, center: rect.center, radius: radius);

  final image = await recorder.endRecording().toImage(
    _size.toInt(),
    _size.toInt(),
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png!.buffer.asUint8List());
}

/// Motiv u krugu [radius] oko [center]; koordinate su u jedinicama tog
/// kruga (-1..1), pa ista geometrija sluzi za obe slike.
void _paintMotif(
  Canvas canvas, {
  required Offset center,
  required double radius,
}) {
  // Ceo motiv pomeren levo da bude vizuelno u sredini (talasi su desno).
  Offset at(double x, double y) =>
      center + Offset((x - 0.12) * radius, y * radius);

  final white = Paint()
    ..color = Colors.white
    ..isAntiAlias = true;

  // "Play" strelica sa zaobljenim uglovima.
  final tip = at(0.1, 0);
  final triangle = Path()
    ..moveTo(at(-0.62, -0.5).dx, at(-0.62, -0.5).dy)
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(at(-0.62, 0.5).dx, at(-0.62, 0.5).dy)
    ..close();
  canvas.drawPath(triangle, white);
  canvas.drawPath(
    triangle,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12 * radius
      ..strokeJoin = StrokeJoin.round,
  );

  // Dva talasa iz vrha strelice.
  final wave = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.12 * radius
    ..strokeCap = StrokeCap.round;
  const sweep = math.pi / 2; // 90°, simetricno oko horizontale
  for (final r in [0.42, 0.72]) {
    canvas.drawArc(
      Rect.fromCircle(center: tip, radius: r * radius),
      -sweep / 2,
      sweep,
      false,
      wave,
    );
  }
}
