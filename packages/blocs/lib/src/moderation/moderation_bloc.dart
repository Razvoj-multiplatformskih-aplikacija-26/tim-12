// Bloc moderatorskog toka: lista soba, snimak sobe, uklanjanje, zatvaranje.
//
// Bloc NE sadrzi pravila: pre svake akcije zove pravila iz domena i tek ako
// sva vaze zove port. Prekrsaj pravila ostaje u podacima kao `ruleError`;
// tehnicki neuspeh porta (izuzetak) vodi u `ModerationError`.
import 'package:bloc/bloc.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import '../ports/proposal_repository.dart';
import '../ports/room_snapshot.dart';
import 'moderation_event.dart';
import 'moderation_state.dart';

final class ModerationBloc extends Bloc<ModerationEvent, ModerationState> {
  ModerationBloc({required ProposalRepository repository})
      : _repository = repository,
        super(const ModerationInitial()) {
    on<ModerationEvent>(
      (event, emit) => switch (event) {
        ModerationStarted() => _onStarted(emit),
        ModerationRoomOpened(:final roomId) => _onRoomOpened(roomId, emit),
        ModerationProposalRemoved(:final proposalId) =>
          _onProposalRemoved(proposalId, emit),
        ModerationRoomClosed(:final roomId) => _onRoomClosed(roomId, emit),
      },
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final ProposalRepository _repository;

  Future<void> _onStarted(Emitter<ModerationState> emit) async {
    emit(const ModerationLoading());
    try {
      emit(ModerationLoaded(rooms: await _repository.loadRooms()));
    } on Exception {
      emit(const ModerationError());
    }
  }

  Future<void> _onRoomOpened(
    RoomId roomId,
    Emitter<ModerationState> emit,
  ) async {
    final rooms = _currentRooms;
    if (rooms == null) return;
    emit(const ModerationLoading());
    try {
      final snapshot = await _repository.loadRoom(roomId);
      emit(_loaded(rooms, snapshot));
    } on Exception {
      emit(const ModerationError());
    }
  }

  Future<void> _onProposalRemoved(
    ProposalId proposalId,
    Emitter<ModerationState> emit,
  ) async {
    final loaded = _currentLoaded;
    final snapshot = loaded?.snapshot;
    if (loaded == null || snapshot == null) return;
    final proposal =
        snapshot.proposals.where((p) => p.id == proposalId).firstOrNull;
    if (proposal == null) return;

    final outcome = checkRemovable(proposal: proposal);
    if (outcome case RuleInvalid(:final error)) {
      emit(loaded.copyWith(ruleError: error));
      return;
    }

    try {
      final removed = await _repository.removeProposal(
        roomId: snapshot.room.id,
        proposalId: proposalId,
      );
      emit(
        _loaded(
          loaded.rooms,
          RoomSnapshot(
            room: snapshot.room,
            round: snapshot.round,
            proposals: [
              for (final p in snapshot.proposals)
                if (p.id == proposalId) removed else p,
            ],
            votes: snapshot.votes,
          ),
        ),
      );
    } on Exception {
      emit(const ModerationError());
    }
  }

  Future<void> _onRoomClosed(
    RoomId roomId,
    Emitter<ModerationState> emit,
  ) async {
    final loaded = _currentLoaded;
    if (loaded == null) return;
    final room = loaded.rooms.where((r) => r.id == roomId).firstOrNull;
    if (room == null) return;

    if (!canTransitionRoom(room.status, const RoomClosed())) {
      emit(loaded.copyWith(ruleError: const RoomNotClosable()));
      return;
    }

    try {
      final closed = await _repository.closeRoom(roomId: roomId);
      final rooms = [
        for (final r in loaded.rooms) if (r.id == roomId) closed else r,
      ];
      final snapshot = loaded.snapshot;
      emit(
        _loaded(
          rooms,
          snapshot == null || snapshot.room.id != roomId
              ? snapshot
              : RoomSnapshot(
                  room: closed,
                  round: snapshot.round,
                  proposals: snapshot.proposals,
                  votes: snapshot.votes,
                ),
        ),
      );
    } on Exception {
      emit(const ModerationError());
    }
  }

  List<Room>? get _currentRooms => switch (state) {
        ModerationLoaded(:final rooms) => rooms,
        _ => null,
      };

  ModerationLoaded? get _currentLoaded =>
      state is ModerationLoaded ? state as ModerationLoaded : null;

  ModerationState _loaded(List<Room> rooms, RoomSnapshot? snapshot) {
    if (snapshot == null) return ModerationLoaded(rooms: rooms);
    return ModerationLoaded(
      rooms: rooms,
      snapshot: snapshot,
      tally: voteTally(
        round: snapshot.round,
        proposals: snapshot.proposals,
        votes: snapshot.votes,
      ),
    );
  }
}
