// Prekrsaj domenskog pravila -> HTTP odgovor `{code, data}`.
//
// Prevod tipa greske u kod i podatke nije ovde, vec u zajednickom paketu
// `packages/mapping` (`apiErrorFromRule`) — isti prevod koji klijent koristi
// u suprotnom smeru (`ruleErrorFromApi`) da napravi poruku. Server zato ne
// moze da posalje kod koji klijent ne bi prepoznao.
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_mapping/radioroom_mapping.dart';
import 'package:relic/relic.dart';

import 'json.dart';

/// Odgovor za prekrsaj pravila; status po kodu (`ErrorCodes.httpStatus`).
Response ruleErrorResponse(ProposalRuleError error) =>
    apiErrorResponse(apiErrorFromRule(error));

/// Prvi prekrsaj iz niza provera, redom kojim korisnik treba da ih vidi.
ProposalRuleError? firstViolation(Iterable<RuleOutcome> outcomes) {
  for (final outcome in outcomes) {
    if (outcome.error case final error?) return error;
  }
  return null;
}
