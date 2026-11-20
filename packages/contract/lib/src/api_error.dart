// Greska servera: kôd + podaci pravila, bez teksta.
//
// Server svaku gresku salje kao `{code, data}` (vidi `apps/server` README
// tabelu kodova i `json.dart`). Poruku za korisnika na srpskom pravi klijent
// iz koda — zato greska nikad ne nosi tekst.
//
// Nepoznat kôd ne sme da srusi staru verziju aplikacije: [ApiError] cuva kôd
// kao `String` (a ne kao enum), pa prosledjivanje nepoznatog koda samo znaci
// da tipizovani prevod u `rule_errors.dart` vrati `null`, a klijent pokaze
// opstu poruku.
final class ApiError {
  const ApiError({required this.code, this.data = const {}});

  /// Masinski kôd greske, npr. `invalid_credentials`. Nepoznat kôd stize
  /// kao obican string — parsiranje nikad ne baca zbog njega.
  final String code;

  /// Podaci pravila uz gresku, npr. `{'role': 'listener'}`. Uvek mapa,
  /// nikad `null`: neispravno `data` iz odgovora postaje prazna mapa.
  final Map<String, Object?> data;

  /// Kôd koji stara verzija sigurno ne poznaje. Koristi se i kao zamena
  /// kad odgovor uopste nema upotrebljiv `code`.
  static const unknownCode = ErrorCodes.unknown;

  /// Da li je kôd jedan od dogovorenih (vidi [ErrorCodes]).
  bool get isKnown => ErrorCodes.all.contains(code);

  /// Cita `{code, data}` oblik. Nikad ne baca: nepoznat kôd prolazi kao
  /// string, a neispravno `data` postaje prazna mapa.
  factory ApiError.fromJson(Map<String, Object?> json) {
    final code = json['code'];
    final data = json['data'];
    return ApiError(
      code: code is String && code.isNotEmpty ? code : unknownCode,
      data: data is Map
          ? {
              for (final entry in data.entries)
                if (entry.key is String) entry.key as String: entry.value,
            }
          : const {},
    );
  }

  Map<String, Object?> toJson() => {'code': code, 'data': data};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiError && other.code == code && _mapsEqual(other.data, data);

  @override
  int get hashCode => Object.hash(code, Object.hashAllUnordered(data.entries));

  @override
  String toString() => 'ApiError($code, $data)';
}

/// Dogovoreni kodovi gresaka (jedno mesto za klijente i server).
///
/// Prijava i sesija: ista tabela kao u `apps/server` README-u. Pravila:
/// isti redosled i imena kao tipovi u `proposal_rules.dart` — prevod zivi
/// u `rule_errors.dart`, ovde su samo stringovi.
abstract final class ErrorCodes {
  // Prijava i sesija.
  static const badRequest = 'bad_request';
  static const invalidCredentials = 'invalid_credentials';
  static const unauthenticated = 'unauthenticated';
  static const sessionExpired = 'session_expired';
  static const userBlocked = 'user_blocked';
  static const backofficeNotAllowed = 'backoffice_not_allowed';

  // Domenska pravila (form-pravila i prava).
  static const tooManyActiveProposals = 'too_many_active_proposals';
  static const recentlyPlayedSong = 'recently_played_song';
  static const invalidVoteTarget = 'invalid_vote_target';
  static const alreadyVotedInRound = 'already_voted_in_round';
  static const proposalNotRemovable = 'proposal_not_removable';
  static const roomNotClosable = 'room_not_closable';
  static const roomNameEmpty = 'room_name_empty';
  static const actionNotAllowed = 'action_not_allowed';
  static const notOwnProposal = 'not_own_proposal';
  static const proposalNotWithdrawable = 'proposal_not_withdrawable';

  /// Zamena za nepoznat kôd ili odgovor bez koda.
  static const unknown = 'unknown_error';

  /// Svi dogovoreni kodovi. Nepoznat kôd nije ovde — to je poenta.
  static const all = {
    badRequest,
    invalidCredentials,
    unauthenticated,
    sessionExpired,
    userBlocked,
    backofficeNotAllowed,
    tooManyActiveProposals,
    recentlyPlayedSong,
    invalidVoteTarget,
    alreadyVotedInRound,
    proposalNotRemovable,
    roomNotClosable,
    roomNameEmpty,
    actionNotAllowed,
    notOwnProposal,
    proposalNotWithdrawable,
    unknown,
  };
}

bool _mapsEqual(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) return false;
  }
  return true;
}
