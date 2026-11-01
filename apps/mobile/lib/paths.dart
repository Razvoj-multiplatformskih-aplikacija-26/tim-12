// Adrese ekrana (go_router). Na jednom mestu da ih ekrani i ruter dele bez
// kruznog uvoza (ruter uvozi ekrane).
import 'package:radioroom_domain/radioroom_domain.dart';

/// Adresa liste predloga sobe.
String roomPath(RoomId roomId) => '/soba/${roomId.value}';

/// Adresa detalja predloga.
String proposalPath(RoomId roomId, ProposalId proposalId) =>
    '${roomPath(roomId)}/predlog/${proposalId.value}';
