import 'package:flutter/material.dart';

void main() {
  runApp(const RadioRoomApp());
}

/// Privremeni pocetni ekran; pravi tok slusaoca stize u celini "mobilna aplikacija".
class RadioRoomApp extends StatelessWidget {
  const RadioRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RadioRoom',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('RadioRoom — slusalac (uskoro: soba i glasanje)'),
        ),
      ),
    );
  }
}
