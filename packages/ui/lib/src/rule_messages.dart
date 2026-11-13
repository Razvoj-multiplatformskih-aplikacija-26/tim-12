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
  ProposalNotRemovable() =>
    'Ovaj predlog je već završen i ne može da se ukloni.',
  RoomNotClosable() => 'Ova soba je već zatvorena.',
  RoomNameEmpty() => 'Naziv sobe ne sme biti prazan.',
  ActionNotAllowed(:final action, :final role) =>
    'Uloga „${_roleName(role)}“ ne može da ${_actionText(action)}.',
  UserBlocked() => 'Tvoj nalog je blokiran.',
  BackofficeNotAllowed(:final role) =>
    'Backoffice je za moderatore. Ovo je nalog ${_roleGenitive(role)} — '
        'prijavi se u mobilnoj aplikaciji.',
  NotOwnProposal() => 'Možeš da povučeš samo svoj predlog.',
  ProposalNotWithdrawable() =>
    'Predlog može da se povuče samo dok čeka ishod runde.',
};

String _roleName(Role role) => switch (role) {
  Role.listener => 'slušalac',
  Role.host => 'host',
  Role.moderator => 'moderator',
};

String _roleGenitive(Role role) => switch (role) {
  Role.listener => 'slušaoca',
  Role.host => 'hosta',
  Role.moderator => 'moderatora',
};

String _actionText(UserAction action) => switch (action) {
  UserAction.propose => 'predlaže pesme',
  UserAction.vote => 'glasa',
  UserAction.withdrawProposal => 'povlači predloge',
  UserAction.createRoom => 'otvara sobe',
  UserAction.removeProposal => 'uklanja predloge',
  UserAction.closeRoom => 'zatvara sobe',
  UserAction.blockUser => 'blokira naloge',
};

String _clockTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';
