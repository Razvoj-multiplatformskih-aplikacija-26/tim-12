// Bloc glavnog toka slusaoca: ucitavanje sobe, predlog pesme, glas i
// povlacenje svog predloga.
//
// Bloc NE sadrzi pravila: pre svake akcije zove pravila iz domena i tek ako
// sva vaze zove port. Prekrsaj pravila (`RuleInvalid`) nije greska ekrana —
// ostaje u podacima kao `ruleError`; tehnicki neuspeh porta (izuzetak) vodi
// u `ProposalsError` sa "Pokusaj ponovo", a serversko odbijanje
// (`ServerRejected`) nosi razlog u stanju i sam osvezava sobu.
//
// "Sad" stize kroz [clock] (ista konvencija kao domen), a korisnik kroz
// konstruktor — u KT1 nema prijave, u KT2 ga daje auth bez izmene ekrana.
// Uloga je potrebna samo pravilu povlacenja (moderator u mobilnoj sme da
// gleda, ali ne povlaci); podrazumevano slusalac, kao u KT1.
import 'package:bloc/bloc.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import '../ports/proposal_repository.dart';
import '../ports/room_snapshot.dart';
import '../ports/server_rejected.dart';
import 'proposal_list_event.dart';
import 'proposal_list_state.dart';

final class ProposalListBloc
    extends Bloc<ProposalListEvent, ProposalListState> {
  ProposalListBloc({
    required ProposalRepository repository,
    required RoomId roomId,
    required UserId currentUser,
    Role currentRole = Role.listener,
    DateTime Function()? clock,
  })  : _repository = repository,
        _roomId = roomId,
        _currentUser = currentUser,
        _currentRole = currentRole,
        _clock = clock ?? DateTime.now,
        super(const ProposalsInitial()) {
    // Jedan handler za sve dogadjaje, redom (ne paralelno): drugi brzi tap
    // na "glasaj" vidi vec upisan prvi glas i pravilo ga odbija.
    on<ProposalListEvent>(
      (event, emit) => switch (event) {
        ProposalsRequested() => _onRequested(emit),
        ProposalAdded(:final song) => _onAdded(song, emit),
        VoteCast(:final proposalId) => _onVoteCast(proposalId, emit),
        ProposalWithdrawn(:final proposalId) =>
          _onWithdrawn(proposalId, emit),
      },
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final ProposalRepository _repository;
  final RoomId _roomId;
  final UserId _currentUser;
  final Role _currentRole;
  final DateTime Function() _clock;

  /// Korisnik za pravila prava; pravila citaju samo ID i ulogu.
  User get _user =>
      User(id: _currentUser, displayName: '', role: _currentRole);

  /// Da li tekuci korisnik sme da povuce [proposal] — isto pravilo koje
  /// Bloc proverava pre poziva porta, pa ekran dugme prikazuje tacno kad
  /// akcija ima smisla.
  bool canWithdraw(Proposal proposal) =>
      checkCanWithdraw(user: _user, proposal: proposal).isValid;

  Future<void> _onRequested(Emitter<ProposalListState> emit) async {
    emit(const ProposalsLoading());
    try {
      emit(_stateFor(await _repository.loadRoom(_roomId)));
    } on ServerRejected catch (rejected) {
      // Odbijeno je samo ucitavanje: automatski reload bi ponovnim
      // zahtevom isla u petlju (npr. istekla sesija odbija svaki put).
      // Razlikuje se od odbijanja akcije — ekran nudi "Pokusaj ponovo".
      emit(ProposalsError(reason: rejected.error));
    } on Exception {
      emit(const ProposalsError());
    }
  }

  Future<void> _onAdded(Song song, Emitter<ProposalListState> emit) async {
    final snapshot = _currentSnapshot;
    if (snapshot == null) return;

    final violation = _firstViolation([
      checkRoomOpen(room: snapshot.room),
      checkMaxActiveProposals(
        proposals: snapshot.proposals,
        userId: _currentUser,
      ),
      checkNotRecentlyPlayed(
        song: song,
        played: snapshot.proposals,
        now: _clock(),
      ),
    ]);
    if (violation != null) {
      emit(_stateFor(snapshot, ruleError: violation));
      return;
    }

    try {
      final proposal = await _repository.propose(
        roomId: _roomId,
        song: song,
        proposedBy: _currentUser,
      );
      emit(
        _stateFor(
          RoomSnapshot(
            room: snapshot.room,
            round: snapshot.round,
            proposals: [...snapshot.proposals, proposal],
            votes: snapshot.votes,
          ),
          // Eksplicitan znak uspeha: tab Pretraga prepoznaje bas ovaj
          // predlog po pesmi, umesto da broji predloge pre i posle.
          lastAdded: proposal,
        ),
      );
    } on ServerRejected catch (rejected) {
      await _onRejected(rejected, emit);
    } on Exception {
      emit(const ProposalsError());
    }
  }

  Future<void> _onVoteCast(
    ProposalId proposalId,
    Emitter<ProposalListState> emit,
  ) async {
    final snapshot = _currentSnapshot;
    if (snapshot == null) return;
    // Glas za predlog van snimka moze doci samo iz baga u UI-ju.
    final proposal =
        snapshot.proposals.where((p) => p.id == proposalId).firstOrNull;
    if (proposal == null) return;

    final violation = _firstViolation([
      checkRoomOpen(room: snapshot.room),
      checkVoteTarget(proposal: proposal),
      checkSingleVotePerRound(
        votes: snapshot.votes,
        voterId: _currentUser,
        roundId: snapshot.round.id,
      ),
    ]);
    if (violation != null) {
      emit(_stateFor(snapshot, ruleError: violation));
      return;
    }

    try {
      final vote = await _repository.vote(
        roundId: snapshot.round.id,
        proposalId: proposalId,
        voterId: _currentUser,
      );
      emit(
        _stateFor(
          RoomSnapshot(
            room: snapshot.room,
            round: snapshot.round,
            proposals: snapshot.proposals,
            votes: [...snapshot.votes, vote],
          ),
        ),
      );
    } on ServerRejected catch (rejected) {
      await _onRejected(rejected, emit);
    } on Exception {
      emit(const ProposalsError());
    }
  }

  Future<void> _onWithdrawn(
    ProposalId proposalId,
    Emitter<ProposalListState> emit,
  ) async {
    final snapshot = _currentSnapshot;
    if (snapshot == null) return;
    final proposal =
        snapshot.proposals.where((p) => p.id == proposalId).firstOrNull;
    if (proposal == null) return;

    final outcome = checkCanWithdraw(user: _user, proposal: proposal);
    if (outcome case RuleInvalid(:final error)) {
      emit(_stateFor(snapshot, ruleError: error));
      return;
    }

    try {
      final withdrawn = await _repository.withdrawProposal(
        roomId: _roomId,
        proposalId: proposalId,
      );
      emit(
        _stateFor(
          RoomSnapshot(
            room: snapshot.room,
            round: snapshot.round,
            proposals: [
              for (final p in snapshot.proposals)
                p.id == withdrawn.id ? withdrawn : p,
            ],
            votes: snapshot.votes,
          ),
        ),
      );
    } on ServerRejected catch (rejected) {
      await _onRejected(rejected, emit);
    } on Exception {
      emit(const ProposalsError());
    }
  }

  /// Server je odbio akciju: razlog ide u stanje, pa Bloc SAM osvezava
  /// sobu. Bez Loading-a — razlog odbijanja ostaje na ekranu dok reload
  /// traje, a sveze stanje stize bez ijednog pritiska korisnika. Lokalni
  /// snimak moze da bude zastareo (npr. neko je izmedju glasao), zato se
  /// poverenje vraca portu.
  Future<void> _onRejected(
    ServerRejected rejected,
    Emitter<ProposalListState> emit,
  ) async {
    emit(ProposalsError(reason: rejected.error));
    try {
      emit(_stateFor(await _repository.loadRoom(_roomId)));
    } on Exception {
      // Razlog je vec na ekranu uz "Pokusaj ponovo"; kvar osvezavanja
      // ga samo zadrzava (nema Loading flash-a ni gubitka razloga).
    }
  }

  /// Snimak nad kojim se proveravaju pravila; van podataka akcija nema smisla.
  RoomSnapshot? get _currentSnapshot => switch (state) {
        ProposalsLoaded(:final snapshot) ||
        ProposalsEmpty(:final snapshot) =>
          snapshot,
        _ => null,
      };

  /// Jedino mesto gde snimak postaje stanje ekrana; broj glasova racuna domen.
  ProposalListState _stateFor(
    RoomSnapshot snapshot, {
    ProposalRuleError? ruleError,
    Proposal? lastAdded,
  }) {
    if (snapshot.proposals.isEmpty) return ProposalsEmpty(snapshot);
    return ProposalsLoaded(
      snapshot: snapshot,
      tally: voteTally(
        round: snapshot.round,
        proposals: snapshot.proposals,
        votes: snapshot.votes,
      ),
      ruleError: ruleError,
      lastAdded: lastAdded,
    );
  }

  /// Prvi prekrsaj iz liste ishoda pravila, ili null kad sva vaze.
  ProposalRuleError? _firstViolation(List<RuleOutcome> outcomes) {
    for (final outcome in outcomes) {
      if (outcome case RuleInvalid(:final error)) return error;
    }
    return null;
  }
}
