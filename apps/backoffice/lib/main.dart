import 'package:flutter/material.dart';

void main() {
  runApp(const RadioRoomBackofficeApp());
}

/// Privremeni pocetni ekran; moderatorski tok stize u celini "backoffice".
class RadioRoomBackofficeApp extends StatelessWidget {
  const RadioRoomBackofficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RadioRoom Backoffice',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Scaffold(
        body: Center(
          child: Text('RadioRoom Backoffice — moderacija (uskoro: tabela soba)'),
        ),
      ),
    );
  }
}
