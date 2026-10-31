// Bloc glavnog toka slusaoca: ucitavanje sobe, predlog pesme, glas.
//
// Bloc NE sadrzi pravila: pre svake akcije zove pravila iz domena i tek ako
// sva vaze zove port. Prekrsaj pravila (`RuleInvalid`) nije greska ekrana —
// ostaje u podacima kao `ruleError`; tehnicki neuspeh porta (izuzetak) vodi
// u `ProposalsError` sa "Pokusaj ponovo".
//
// "Sad" stize kroz [clock] (ista konvencija kao domen), a korisnik kroz
// konstruktor — u KT1 nema prijave, u KT2 ga daje auth bez izmene ekrana.
import 'package:bloc/bloc.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import '../ports/proposal_repository.dart';
import '../ports/room_snapshot.dart';
import 'proposal_list_event.dart';
import 'proposal_list_state.dart';

final class ProposalListBloc
    extends Bloc<ProposalListEvent, ProposalListState> {
  ProposalListBloc({
    required ProposalRepository repository,
    required RoomId roomId,
    required UserId currentUser,
    DateTime Function()? clock,
  })  : _repository = repository,
        _roomId = roomId,
        _currentUser = currentUser,
        _clock = clock ?? DateTime.now,
        super(const ProposalsInitial()) {
    // Jedan handler za sve dogadjaje, redom (ne paralelno): drugi brzi tap
    // na "glasaj" vidi vec upisan prvi glas i pravilo ga odbija.
    on<ProposalListEvent>(
      (event, emit) => switch (event) {
        ProposalsRequested() => _onRequested(emit),
        ProposalAdded(:final song) => _onAdded(song, emit),
        VoteCast(:final proposalId) => _onVoteCast(proposalId, emit),
      },
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final ProposalRepository _repository;
  final RoomId _roomId;
  final UserId _currentUser;
  final DateTime Function() _clock;

  Future<void> _onRequested(Emitter<ProposalListState> emit) async {
    emit(const ProposalsLoading());
    try {
      emit(_stateFor(await _repository.loadRoom(_roomId)));
    } on Exception {
      emit(const ProposalsError());
    }
  }

  Future<void> _onAdded(Song song, Emitter<ProposalListState> emit) async {
    final snapshot = _currentSnapshot;
    if (snapshot == null) return;

    final violation = _firstViolation([
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
        ),
      );
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
    } on Exception {
      emit(const ProposalsError());
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
