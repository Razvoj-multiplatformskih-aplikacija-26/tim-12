// Prevod domen<->ugovor: svaki tip greske pravila ima kôd i podatke,
// a nazad se nepoznat kôd ili osteceni podaci svode na `null`
// (opsta poruka) umesto pada stare verzije.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

void main() {
  test('svaki tip greske ima svoj kôd i nosi podatke', () {
    final cases = <ProposalRuleError, String>{
      const TooManyActiveProposals(activeCount: 3, limit: 3):
          ErrorCodes.tooManyActiveProposals,
      RecentlyPlayedSong(
        song: const Song(title: 'Fuego', artist: 'Severina'),
        playedAt: DateTime.utc(2026, 11, 20, 10),
      ): ErrorCodes.recentlyPlayedSong,
      const InvalidVoteTarget(proposalId: ProposalId('p1')):
          ErrorCodes.invalidVoteTarget,
      const AlreadyVotedInRound(
        voterId: UserId('u1'),
        roundId: RoundId('rd1'),
      ): ErrorCodes.alreadyVotedInRound,
      const ProposalNotRemovable(proposalId: ProposalId('p1')):
          ErrorCodes.proposalNotRemovable,
      const RoomNotClosable(): ErrorCodes.roomNotClosable,
      const RoomNameEmpty(): ErrorCodes.roomNameEmpty,
      const ActionNotAllowed(action: UserAction.vote, role: Role.listener):
          ErrorCodes.actionNotAllowed,
      const UserBlocked(): ErrorCodes.userBlocked,
      const BackofficeNotAllowed(role: Role.listener):
          ErrorCodes.backofficeNotAllowed,
      const NotOwnProposal(proposalId: ProposalId('p1')):
          ErrorCodes.notOwnProposal,
      const ProposalNotWithdrawable(proposalId: ProposalId('p1')):
          ErrorCodes.proposalNotWithdrawable,
      const RoomNotOpen(status: RoomPaused()): ErrorCodes.roomNotOpen,
      const RoundClosed(roundId: RoundId('rd1')): ErrorCodes.roundClosed,
    };

    for (final entry in cases.entries) {
      final error = apiErrorFromRule(entry.key);
      expect(error.code, entry.value, reason: '${entry.key}');
      expect(error.isKnown, isTrue);
    }
  });

  test('krug domen->ugovor->domen cuva tip i podatke', () {
    const original = TooManyActiveProposals(activeCount: 3, limit: 3);

    final back = ruleErrorFromApi(apiErrorFromRule(original));

    expect(back, isA<TooManyActiveProposals>());
    expect((back as TooManyActiveProposals).activeCount, 3);
    expect(back.limit, 3);
  });

  test('krug room_not_open i round_closed cuva stanje i rundu', () {
    final backOpen = ruleErrorFromApi(
      apiErrorFromRule(const RoomNotOpen(status: RoomClosed())),
    );
    expect(backOpen, isA<RoomNotOpen>());
    expect((backOpen as RoomNotOpen).status, isA<RoomClosed>());

    final backRound = ruleErrorFromApi(
      apiErrorFromRule(const RoundClosed(roundId: RoundId('rd9'))),
    );
    expect(backRound, isA<RoundClosed>());
    expect((backRound as RoundClosed).roundId, const RoundId('rd9'));

    // Osteceno stanje sobe daje null.
    expect(
      ruleErrorFromApi(
        const ApiError(
          code: ErrorCodes.roomNotOpen,
          data: {'status': 'nepoznato'},
        ),
      ),
      isNull,
    );
  });

  test('already_voted sa serverskog zice (samo roundId) daje tip', () {
    final back = ruleErrorFromApi(
      const ApiError(
        code: ErrorCodes.alreadyVotedInRound,
        data: {'roundId': 'rd1'},
      ),
    );
    expect(back, isA<AlreadyVotedInRound>());
    expect((back as AlreadyVotedInRound).roundId, const RoundId('rd1'));
  });

  test('nepoznat kôd daje null (stara verzija ne pada)', () {
    expect(
      ruleErrorFromApi(const ApiError(code: 'buduce_pravilo')),
      isNull,
    );
  });

  test('osteceni podaci daju null umesto pada', () {
    expect(
      ruleErrorFromApi(
        const ApiError(
          code: ErrorCodes.tooManyActiveProposals,
          data: {'activeCount': 'mnogo'},
        ),
      ),
      isNull,
    );
    expect(
      ruleErrorFromApi(
        const ApiError(
          code: ErrorCodes.actionNotAllowed,
          data: {'action': 'hakovanje', 'role': 'listener'},
        ),
      ),
      isNull,
    );
    expect(
      ruleErrorFromApi(
        const ApiError(
          code: ErrorCodes.recentlyPlayedSong,
          data: {'title': 'Fuego'},
        ),
      ),
      isNull,
    );
  });
}
