// Trenutno pustanje — izvodjenje iz domenskih podataka, prvenstveno za
// view mod (veliki ekran: TV/auto prikazuje rundu i pesmu koja trenutno ide).
//
// KT1: cista projekcija nad listom predloga, bez I/O. Isto pravilo nasledjuju
// server (KT2) i host offline (KT3): "trenutna" je poslednja pustena pesma
// cije je vreme pustanja proslo.
import 'proposal.dart';
import 'proposal_status.dart';

/// Trenutno pustena pesma: poslednji predlog sa statusom `Played` cije je
/// vreme pustanja stiglo (buducnost se ignorise — granica se ne veruje).
/// Kad nista nije pusteno (ili je sve u buducnosti): null.
Proposal? currentPlaying({
  required List<Proposal> proposals,
  required DateTime now,
}) {
  Proposal? current;
  DateTime? currentAt;
  for (final p in proposals) {
    final status = p.status;
    if (status is! Played) continue;
    if (status.playedAt.isAfter(now)) continue;
    if (currentAt == null || status.playedAt.isAfter(currentAt)) {
      current = p;
      currentAt = status.playedAt;
    }
  }
  return current;
}
