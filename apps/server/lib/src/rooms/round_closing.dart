// Zatvaranje runde: pobednika konacno bira server, iz glasova svih
// slusalaca.
//
// Lenjo, pri prvom pristupu sobi posle isteka runde (citanje ili upis), u
// istoj transakciji i pod istim zakljucavanjem sobe kao i upis. Dva klijenta
// koja stignu u trenutku isteka zato ne mogu da zatvore rundu dva puta:
// drugi ceka zakljucavanje i vidi vec novu rundu. Odbaceno: tajmer na
// serveru — ima sopstveni zivotni ciklus i tesko se testira, a ishod je isti.
//
// Ko pobedjuje i ko se prenosi odlucuje domen (`resolveRound`, `carryOver`);
// ovde je samo upis tog ishoda.
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import 'room_store.dart';

/// Zatvara rundu iz [view] ako je istekla i soba je otvorena, i otvara
/// sledecu od [now] u trajanju [roundLength]. Vraca da li je zatvarala.
/// Pozivalac drzi zakljucavanje sobe ([lockRoom]).
///
/// Runda bez ijednog glasa nikoga ne odbija: predlozi u glasanju prelaze u
/// sledecu rundu (inace bi `carryOver`, koji prenosi samo gubitnike sa
/// glasom, izbacio sve predloge prazne runde).
Future<bool> closeExpiredRound(
  Session tx,
  RoomView view, {
  required DateTime now,
  required Duration roundLength,
}) async {
  if (view.room.status is! RoomOpen) return false;
  if (now.isBefore(view.round.endsAt)) return false;

  final inVoting = view.proposals.where((p) => p.status is InVoting).toList();
  final outcome = resolveRound(
    round: view.round,
    proposals: inVoting,
    votes: view.votes,
  );

  if (outcome case RoundWinner(:final proposal)) {
    final losers = [
      for (final p in inVoting)
        if (p.id != proposal.id) p.withStatus(const Rejected()),
    ];
    await setProposalStatus(tx, proposal.id, const Winner());
    for (final loser in losers) {
      await setProposalStatus(tx, loser.id, const Rejected());
    }
    final carried = carryOver(
      rejected: losers,
      round: view.round,
      votes: view.votes,
      newIdFor: (_) => ProposalId(newId()),
      now: now,
    );
    for (final fresh in carried) {
      await insertProposal(tx, fresh);
    }
  }

  await insertRound(
    tx,
    Round(
      id: RoundId(newId()),
      roomId: view.room.id,
      startsAt: now,
      endsAt: now.add(roundLength),
    ),
  );
  // Sve sto ceka (novi predlozi i preneti gubitnici) ulazi u novu rundu.
  await tx.execute(
    Sql.named(
      "UPDATE proposals SET status = 'in_voting' "
      "WHERE room_id = @room AND status = 'proposed'",
    ),
    parameters: {'room': view.room.id.value},
  );
  return true;
}

final _random = Random.secure();

/// Novi ID u obliku UUID v4 (domen ID-jeve ne izmislja — daje ih server).
String newId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
