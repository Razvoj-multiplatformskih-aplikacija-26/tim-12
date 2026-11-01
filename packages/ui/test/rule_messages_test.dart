// Poruke pravila: svaki tip greske daje srpski tekst sa podacima iz greske.
import 'package:flutter_test/flutter_test.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

void main() {
  test('max aktivnih predloga: broj i limit iz greske', () {
    expect(
      ruleMessage(const TooManyActiveProposals(activeCount: 3, limit: 3)),
      'Dostignut je limit aktivnih predloga (3/3). Sačekaj ishod runde.',
    );
  });

  test('nedavno pustena: naslov i vreme pustanja', () {
    expect(
      ruleMessage(
        RecentlyPlayedSong(
          song: const Song(title: 'Bohemian Rhapsody', artist: 'Queen'),
          playedAt: DateTime(2026, 10, 31, 19, 5),
        ),
      ),
      '„Bohemian Rhapsody“ je puštena u 19:05. '
      'Ista pesma ne može ponovo u roku od sat vremena.',
    );
  });

  test('glas za predlog van glasanja', () {
    expect(
      ruleMessage(const InvalidVoteTarget(proposalId: ProposalId('p6'))),
      'Za ovaj predlog se trenutno ne glasa.',
    );
  });

  test('drugi glas u rundi', () {
    expect(
      ruleMessage(
        const AlreadyVotedInRound(
          voterId: UserId('u1'),
          roundId: RoundId('rd2'),
        ),
      ),
      'Tvoj glas u ovoj rundi je već zabeležen.',
    );
  });

  test('uklanjanje zavrsenog predloga', () {
    expect(
      ruleMessage(const ProposalNotRemovable(proposalId: ProposalId('p10'))),
      'Ovaj predlog je već završen i ne može da se ukloni.',
    );
  });

  test('zatvaranje zatvorene sobe', () {
    expect(
      ruleMessage(const RoomNotClosable()),
      'Ova soba je već zatvorena.',
    );
  });

  test('prazan naziv sobe', () {
    expect(
      ruleMessage(const RoomNameEmpty()),
      'Naziv sobe ne sme biti prazan.',
    );
  });
}
