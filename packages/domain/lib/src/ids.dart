// Identifikatori domenskih pojmova.
//
// Svaki pojam ima svoj tip ID-ja (String omotnica): tipovi se ne mogu
// zameniti greskom (npr. `ProposalId` ne moze tamo gde se trazi `RoomId`),
// a u KT1 su obicne kratke vrednosti poput 'p1'. UUID stize tek u KT2
// i ne menja ove tipove — samo nacin pravljenja vrednosti.
extension type const ProposalId(String value) {}

/// Identifikator sobe.
extension type const RoomId(String value) {}

/// Identifikator korisnika (slusalac, host, moderator — uloga je van KT1).
extension type const UserId(String value) {}

/// Identifikator glasa.
extension type const VoteId(String value) {}

/// Identifikator runde glasanja.
extension type const RoundId(String value) {}
