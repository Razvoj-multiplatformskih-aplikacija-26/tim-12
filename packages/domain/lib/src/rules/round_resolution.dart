// Izracunavanje runde: ko je pobednik i koji glasovi vaze.
//
// Server-zavisna pravila iz teme: pobednika odredjuju glasovi svih slusalaca,
// neresen rezultat lomi ranije predlozena pesma, glas posle zatvaranja runde
// se odbacuje. U KT1 ovo su cista izracunavanja nad listama (konacnu odluku
// donosi server tek u KT2) — zato zive u odvojenom fajlu od form-pravila:
// granica buduce selidbe na server vidi se golim okom.
import '../ids.dart';
import '../proposal.dart';
import '../round.dart';
import '../vote.dart';

/// Ishod razresenja runde: pobednik ili runde bez pobednika.
sealed class RoundOutcome {
  const RoundOutcome();
}

/// Pobednik proglasen — nosi predlog i broj vazecih glasova.
final class RoundWinner extends RoundOutcome {
  const RoundWinner({required this.proposal, required this.voteCount});

  final Proposal proposal;
  final int voteCount;
}

/// Bez pobednika — nijedan vazeci glas (prazna runda ili samo kasni glasovi).
final class RoundWithoutWinner extends RoundOutcome {
  const RoundWithoutWinner();
}

/// Vazeći glasovi runde: glasovi te runde koji nisu stigli posle njenog kraja.
///
/// Rano pristigli glasovi (pre pocetka runde) ovde se ne filtriraju — za njih
/// specifikacija cuti, pa odluka ostaje serveru u KT2.
List<Vote> validVotes({required Round round, required List<Vote> votes}) =>
    votes
        .where((v) => v.roundId == round.id && !round.isLate(v.castAt))
        .toList();

/// Razresava rundu: broji vazece glasove po predlogu, pobednik je predlog sa
/// najvise glasova. Neresen rezultat (odluka O7): sortiranje (glasovi
/// opadajuce, vreme predlaganja rastuce), pa za potpuni determinizam jos
/// i identifikator — isti ulaz uvek daje istog pobednika.
///
/// Glasovi za predloge van prosledjene liste ignorisu se (odbrambeno:
/// pogresna lista ne sme srusiti obracun). Bez ijednog vaznog glasa —
/// [RoundWithoutWinner].
RoundOutcome resolveRound({
  required Round round,
  required List<Proposal> proposals,
  required List<Vote> votes,
}) {
  final byId = <ProposalId, Proposal>{for (final p in proposals) p.id: p};
  final counts = <ProposalId, int>{};
  for (final v in validVotes(round: round, votes: votes)) {
    if (!byId.containsKey(v.proposalId)) continue;
    counts[v.proposalId] = (counts[v.proposalId] ?? 0) + 1;
  }
  if (counts.isEmpty) return const RoundWithoutWinner();
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byVotes = b.value.compareTo(a.value);
      if (byVotes != 0) return byVotes;
      final byTime = byId[a.key]!.proposedAt.compareTo(
        byId[b.key]!.proposedAt,
      );
      if (byTime != 0) return byTime;
      return a.key.value.compareTo(b.key.value);
    });
  final first = ranked.first;
  return RoundWinner(proposal: byId[first.key]!, voteCount: first.value);
}
