// Poruke pravila na srpskom — jedino mesto gde tip greske postaje tekst.
//
// Pravila zive u domenu i vracaju gresku kao TIP; aplikacija bira samo
// tekst. Podaci u poruci (broj, limit, pesma, vreme) stizu iz same greske,
// pa se vrednosti pravila ne ponavljaju ovde: promena limita u domenu
// automatski menja i poruku.
import 'package:radioroom_domain/radioroom_domain.dart';

/// Tekst poruke za prekrsaj pravila. Exhaustive switch nad sealed tipom:
/// novo pravilo u domenu je greska kompajliranja ovde dok se ne doda poruka.
String ruleMessage(ProposalRuleError error) => switch (error) {
  TooManyActiveProposals(:final activeCount, :final limit) =>
    'Dostignut je limit aktivnih predloga ($activeCount/$limit). '
        'Sačekaj ishod runde.',
  RecentlyPlayedSong(:final song, :final playedAt) =>
    '„${song.title}“ je puštena u ${_clockTime(playedAt)}. '
        'Ista pesma ne može ponovo u roku od sat vremena.',
  InvalidVoteTarget() => 'Za ovaj predlog se trenutno ne glasa.',
  AlreadyVotedInRound() => 'Tvoj glas u ovoj rundi je već zabeležen.',
};

String _clockTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';
