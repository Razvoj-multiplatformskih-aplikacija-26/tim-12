// Stanja i uloge: domenski tip <-> string na mrezi.
//
// Iste reci koristi i baza na serveru (kolone `status` i `role`), pa server
// ove funkcije koristi i za citanje i upis redova.
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

/// Stanje predloga u kod; `playedAt` iz [Played] ide u posebno polje.
String proposalStatusToCode(ProposalStatus status) => switch (status) {
  Proposed() => ProposalStatusCodes.proposed,
  InVoting() => ProposalStatusCodes.inVoting,
  Winner() => ProposalStatusCodes.winner,
  Played() => ProposalStatusCodes.played,
  Rejected() => ProposalStatusCodes.rejected,
  Removed() => ProposalStatusCodes.removed,
};

/// Kod stanja predloga u tip; `null` za nepoznat kod ili `played` bez
/// vremena.
ProposalStatus? proposalStatusFromCode(String code, {DateTime? playedAt}) =>
    switch (code) {
      ProposalStatusCodes.proposed => const Proposed(),
      ProposalStatusCodes.inVoting => const InVoting(),
      ProposalStatusCodes.winner => const Winner(),
      ProposalStatusCodes.played => playedAt == null ? null : Played(playedAt),
      ProposalStatusCodes.rejected => const Rejected(),
      ProposalStatusCodes.removed => const Removed(),
      _ => null,
    };

String roomStatusToCode(RoomStatus status) => switch (status) {
  RoomOpen() => RoomStatusCodes.open,
  RoomPaused() => RoomStatusCodes.paused,
  RoomClosed() => RoomStatusCodes.closed,
};

/// Kod stanja sobe u tip; `null` za nepoznat kod.
RoomStatus? roomStatusFromCode(Object? code) => switch (code) {
  RoomStatusCodes.open => const RoomOpen(),
  RoomStatusCodes.paused => const RoomPaused(),
  RoomStatusCodes.closed => const RoomClosed(),
  _ => null,
};

String roleToCode(Role role) => switch (role) {
  Role.listener => RoleCodes.listener,
  Role.host => RoleCodes.host,
  Role.moderator => RoleCodes.moderator,
};

/// Kod uloge u tip; `null` za nepoznat kod.
Role? roleFromCode(Object? code) => switch (code) {
  RoleCodes.listener => Role.listener,
  RoleCodes.host => Role.host,
  RoleCodes.moderator => Role.moderator,
  _ => null,
};
