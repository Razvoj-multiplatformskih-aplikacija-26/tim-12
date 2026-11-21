// Zajednicki ugovor klijent-server sistema RadioRoom.
//
// ApiError (kôd + podaci, bez teksta), DTO zahteva i odgovora i kodovi
// stanja i uloga na mrezi. Cist Dart: ne uvozi domen, Flutter ni `dart:io`.
// Prevod domen <-> ugovor (i za greske) je u `packages/mapping`.
library;

export 'src/api_error.dart';
export 'src/auth_dto.dart';
export 'src/proposal_dto.dart';
export 'src/room_dto.dart';
export 'src/wire_codes.dart';
