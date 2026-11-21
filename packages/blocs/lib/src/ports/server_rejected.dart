// Serversko odbijanje zahteva — tipizovana greska porta.
//
// Implementacija porta baca [ServerRejected] kad server odbije zahtev
// pravilom ili sesijom: razlog stize kao `{code, data}` iz ugovora
// ([ApiError]), bez teksta — poruku na srpskom bira aplikacija
// (`serverMessage` iz `radioroom_ui`). Tehnicki kvar ostaje genericki
// `Exception`: njega ne prati razlog ni reload.
//
// Nepoznat kod ne rusi starog klijenta: [ApiError] cuva kod kao String,
// pa je i nepoznato odbijanje samo odbijanje sa opstim razlogom.
import 'package:radioroom_contract/radioroom_contract.dart';

/// Server je odbio zahtev; [error] nosi kod i podatke pravila.
final class ServerRejected implements Exception {
  const ServerRejected(this.error);

  final ApiError error;

  @override
  String toString() => 'ServerRejected($error)';
}
