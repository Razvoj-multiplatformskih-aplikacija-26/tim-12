// Izracunavanje runde: ko je pobednik i koji glasovi vaze.
//
// Server-zavisna pravila iz teme: pobednika odredjuju glasovi svih slusalaca,
// neresen rezultat lomi ranije predlozena pesma, glas posle zatvaranja runde
// se odbacuje. U KT1 ovo su cista izracunavanja nad listama (konacnu odluku
// donosi server tek u KT2) — zato zive u odvojenom fajlu od form-pravila:
// granica buduce selidbe na server vidi se golim okom.
import '../ids.dart';
import '../proposal.dart';
import '../proposal_status.dart';
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

/// Broj vazecih glasova po predlogu runde — leaderboard za view mod.
///
/// Istu tabelu koristi i [resolveRound] (jedna prica o brojanju na oba mesta):
/// view mod iz nje crta leaderboard, `resolveRound` iz nje bira pobednika.
/// Glasovi za predloge van prosledjene liste ignorisu se (granica se ne veruje).
Map<ProposalId, int> voteTally({
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
  return counts;
}

/// Razresava rundu: pobednik je predlog sa najvise vazecih glasova
/// (vise u [voteTally]). Neresen rezultat (odluka O7): sortiranje (glasovi
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
  final counts = voteTally(round: round, proposals: proposals, votes: votes);
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

/// Prenos gubitnika u sledecu rundu ("druga sansa").
///
/// Gubitnik sa podrskom (bar 1 vazeci glas) vraca se kao SVEZ predlog: novi
/// ID (od [newIdFor]), sadasnji [now] kao `proposedAt`, isti song/soba/
/// predlagac, status `Proposed`. Nula glasova i fer tie-break dobijaju se
/// strukturom (glasovi su vezani za rundu i stari ID), bez ikakvog koda za
/// reset. Gubitnik bez glasova ispada; ne-`Rejected` u ulazu ignorise se.
///
/// Redosled: rang runde (glasovi opadajuce, vreme rastuce, ID), pa kap
/// [maxCarry] (default 5; 0 = prenos iskljucen, u KT2 se seli u RoomSettings).
/// ID-jeve donosi pozivalac (u KT2 server sa UUID) — domen ih ne izmislja.
List<Proposal> carryOver({
  required List<Proposal> rejected,
  required Round round,
  required List<Vote> votes,
  required ProposalId Function(Proposal former) newIdFor,
  required DateTime now,
  int maxCarry = 5,
}) {
  assert(maxCarry >= 0, 'maxCarry ne moze biti negativan');
  if (maxCarry == 0) return const [];
  final counts = <ProposalId, int>{};
  for (final v in validVotes(round: round, votes: votes)) {
    counts[v.proposalId] = (counts[v.proposalId] ?? 0) + 1;
  }
  final ranked = rejected
      .where((p) => p.status is Rejected && (counts[p.id] ?? 0) > 0)
      .toList()
    ..sort((a, b) {
      final byVotes = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
      if (byVotes != 0) return byVotes;
      final byTime = a.proposedAt.compareTo(b.proposedAt);
      if (byTime != 0) return byTime;
      return a.id.value.compareTo(b.id.value);
    });
  return ranked
      .take(maxCarry)
      .map(
        (p) => Proposal(
          id: newIdFor(p),
          roomId: p.roomId,
          song: p.song,
          proposedBy: p.proposedBy,
          proposedAt: now,
          status: const Proposed(),
        ),
      )
      .toList();
}
