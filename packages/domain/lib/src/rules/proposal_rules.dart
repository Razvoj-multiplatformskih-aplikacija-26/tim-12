// Form-pravila: provere pri unosu (odluke O5, O6).
//
// Svako pravilo je jedna imenovana funkcija koja vraca [RuleOutcome]:
// uspeh ili gresku kao TIP (sealed hijerarhija), nikad `String` poruku.
// Tekst poruke na srpskom bira aplikacija (mobilna/backoffice) na osnovu
// tipa greske — zato greska nosi podatke (koliko, kada, ko), a ne recenicu.
//
// Sva vremena stizu kao parametri ("sad" se prosledjuje): pravila ne citaju
// sistemski sat pa su deterministicki testabilna.
import 'ids.dart';
import 'proposal.dart';
import 'proposal_status.dart';
import 'vote.dart';

/// Ishod provere pravila: ili vazi, ili nosi tacan razlog.
sealed class RuleOutcome {
  const RuleOutcome();

  bool get isValid;
  ProposalRuleError? get error;
}

/// Pravilo zadovoljeno.
final class RuleValid extends RuleOutcome {
  const RuleValid();

  @override
  bool get isValid => true;

  @override
  ProposalRuleError? get error => null;
}

/// Pravilo prekrseno — razlog je u [error].
final class RuleInvalid extends RuleOutcome {
  const RuleInvalid(this.error);

  @override
  final ProposalRuleError error;

  @override
  bool get isValid => false;
}

/// Razlozi prekrsaja, kao tipovi (svaki nosi podatke za test i za poruku).
sealed class ProposalRuleError {
  const ProposalRuleError();
}

/// Slusalac vec ima previse aktivnih predloga.
final class TooManyActiveProposals extends ProposalRuleError {
  const TooManyActiveProposals({required this.activeCount, required this.limit});

  final int activeCount;
  final int limit;
}

/// Pesma je pustena nedavno — re-predlog je zabranjen dok ne istekne rok.
final class RecentlyPlayedSong extends ProposalRuleError {
  RecentlyPlayedSong({
    required this.title,
    required this.artist,
    required this.playedAt,
  });

  final String title;
  final String artist;
  final DateTime playedAt;
}

/// Slusalac je u ovoj rundi vec glasao.
final class AlreadyVotedInRound extends ProposalRuleError {
  const AlreadyVotedInRound({required this.voterId, required this.roundId});

  final UserId voterId;
  final RoundId roundId;
}

/// Najvise [limit] aktivnih predloga po slusaocu (odluka O6: aktivan =
/// predlozena ili u glasanju). Proverava se PRE pravljenja novog predloga,
/// zato prekrsaj nastaje vec kad broj dostigne limit.
RuleOutcome checkMaxActiveProposals({
  required List<Proposal> proposals,
  required UserId userId,
  int limit = 3,
}) {
  final activeCount = proposals
      .where((p) => p.proposedBy == userId && p.isActive)
      .length;
  if (activeCount >= limit) {
    return RuleInvalid(
      TooManyActiveProposals(activeCount: activeCount, limit: limit),
    );
  }
  return const RuleValid();
}

/// Zabranjuje re-predlog pesme pustene u poslednjih [cooldown] (odluka O5:
/// 1 sat, kao u README). Poredi se normalizovano (bez velikih/malih slova
/// i okolnih razmaka); trenutak pustanja cita se iz statusa `Played`.
RuleOutcome checkNotRecentlyPlayed({
  required String title,
  required String artist,
  required List<Proposal> played,
  required DateTime now,
  Duration cooldown = const Duration(hours: 1),
}) {
  for (final p in played) {
    final status = p.status;
    if (status is! Played) continue;
    if (!_sameSong(p.title, p.artist, title, artist)) continue;
    if (status.playedAt.isAfter(now)) continue;
    if (now.difference(status.playedAt) < cooldown) {
      return RuleInvalid(
        RecentlyPlayedSong(
          title: p.title,
          artist: p.artist,
          playedAt: status.playedAt,
        ),
      );
    }
  }
  return const RuleValid();
}

/// Jedan glas po rundi po slusaocu: u listi glasova ne sme postojati glas
/// istog slusaoca u istoj rundi. Zakasnelost glasa ne proverava se ovde —
/// to radi izracunavanje runde u `round_resolution.dart` (D5).
RuleOutcome checkSingleVotePerRound({
  required List<Vote> votes,
  required UserId voterId,
  required RoundId roundId,
}) {
  final already = votes.any(
    (v) => v.voterId == voterId && v.roundId == roundId,
  );
  if (already) {
    return RuleInvalid(AlreadyVotedInRound(voterId: voterId, roundId: roundId));
  }
  return const RuleValid();
}

bool _sameSong(String aTitle, String aArtist, String bTitle, String bArtist) =>
    _normalized(aTitle) == _normalized(bTitle) &&
    _normalized(aArtist) == _normalized(bArtist);

String _normalized(String value) => value.trim().toLowerCase();
