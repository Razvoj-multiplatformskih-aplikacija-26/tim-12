// Zajednicki ugovor klijent-server sistema RadioRoom.
//
// ApiError (kôd + podaci, bez teksta), DTO zahteva i odgovora u dogovorenom
// `{code, data}` formatu i prevod domenskih tipova u ugovor i nazad.
// Pravila ostaju u `radioroom_domain` — ovaj paket ih samo prenosi.
library;

export 'src/api_error.dart';
export 'src/auth_dto.dart';
export 'src/proposal_dto.dart';
export 'src/room_dto.dart';
export 'src/rule_errors.dart';
