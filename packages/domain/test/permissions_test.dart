// Prava: za svaku akciju svaka uloga, plus blokiran nalog i tudj predlog.
//
// Tabela ocekivanja je namerno ispisana rukom (a ne izvedena iz
// `allowedRoles`): test mora da padne kad se prava promene, da promena
// bude svesna odluka i na odbrani i u diff-u.
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:test/test.dart';

User _user(Role role, {String id = 'u1', bool blocked = false}) => User(
      id: UserId(id),
      displayName: id,
      role: role,
      blocked: blocked,
    );

Proposal _proposal({
  UserId by = const UserId('u1'),
  ProposalStatus status = const Proposed(),
}) =>
    Proposal(
      id: const ProposalId('p1'),
      roomId: const RoomId('r1'),
      song: const Song(title: 'Fuego', artist: 'Eleni Foureira'),
      proposedBy: by,
      proposedAt: DateTime.utc(2026, 11, 13, 20),
      status: status,
    );

void main() {
  group('checkAllowed', () {
    const expected = {
      UserAction.propose: {Role.listener, Role.host},
      UserAction.vote: {Role.listener, Role.host},
      UserAction.withdrawProposal: {Role.listener, Role.host},
      UserAction.createRoom: {Role.host},
      UserAction.removeProposal: {Role.moderator},
      UserAction.closeRoom: {Role.moderator},
      UserAction.blockUser: {Role.moderator},
    };

    for (final action in UserAction.values) {
      for (final role in Role.values) {
        final allowed = expected[action]!.contains(role);
        test('${role.name} ${allowed ? 'sme' : 'ne sme'} ${action.name}', () {
          final outcome = checkAllowed(user: _user(role), action: action);

          if (allowed) {
            expect(outcome, isA<RuleValid>());
          } else {
            expect(
              outcome.error,
              isA<ActionNotAllowed>()
                  .having((e) => e.action, 'action', action)
                  .having((e) => e.role, 'role', role),
            );
          }
        });
      }
    }

    test('blokiran nalog ne sme nista, ni ono sto mu uloga dozvoljava', () {
      for (final action in UserAction.values) {
        for (final role in Role.values) {
          expect(
            checkAllowed(user: _user(role, blocked: true), action: action)
                .error,
            isA<UserBlocked>(),
          );
        }
      }
    });
  });

  group('checkCanUseBackoffice', () {
    test('moderator ulazi', () {
      expect(
        checkCanUseBackoffice(user: _user(Role.moderator)),
        isA<RuleValid>(),
      );
    });

    for (final role in [Role.listener, Role.host]) {
      test('${role.name} ne ulazi i greska kaze njegovu ulogu', () {
        expect(
          checkCanUseBackoffice(user: _user(role)).error,
          isA<BackofficeNotAllowed>().having((e) => e.role, 'role', role),
        );
      });
    }

    test('blokiran moderator ne ulazi', () {
      expect(
        checkCanUseBackoffice(user: _user(Role.moderator, blocked: true)).error,
        isA<UserBlocked>(),
      );
    });
  });

  group('checkCanWithdraw', () {
    test('slusalac povlaci svoj predlog koji ceka ishod', () {
      for (final status in [const Proposed(), const InVoting()]) {
        expect(
          checkCanWithdraw(
            user: _user(Role.listener),
            proposal: _proposal(status: status),
          ),
          isA<RuleValid>(),
        );
      }
    });

    test('tudj predlog se ne povlaci', () {
      expect(
        checkCanWithdraw(
          user: _user(Role.listener),
          proposal: _proposal(by: const UserId('u2')),
        ).error,
        isA<NotOwnProposal>(),
      );
    });

    test('pobednik i zavrseni predlozi se ne povlace', () {
      for (final status in [
        const Winner(),
        Played(DateTime.utc(2026, 11, 13, 20)),
        const Rejected(),
        const Removed(),
      ]) {
        expect(
          checkCanWithdraw(
            user: _user(Role.listener),
            proposal: _proposal(status: status),
          ).error,
          isA<ProposalNotWithdrawable>(),
          reason: '$status',
        );
      }
    });

    test('moderator ne povlaci (on uklanja) — greska je uloga', () {
      expect(
        checkCanWithdraw(
          user: _user(Role.moderator),
          proposal: _proposal(),
        ).error,
        isA<ActionNotAllowed>(),
      );
    });

    test('tudj zavrsen predlog: prvo se kaze da nije tvoj', () {
      expect(
        checkCanWithdraw(
          user: _user(Role.listener),
          proposal: _proposal(by: const UserId('u2'), status: const Rejected()),
        ).error,
        isA<NotOwnProposal>(),
      );
    });
  });
}
