// Bloc home toka: lista soba + pravljenje nove.
//
// Bloc NE sadrzi pravila: naziv proverava domenom pre poziva porta.
// Prekrsaj ostaje u podacima kao `ruleError`; tehnicki neuspeh porta
// (izuzetak) vodi u `RoomsError`.
import 'package:bloc/bloc.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

import '../ports/proposal_repository.dart';
import 'rooms_event.dart';
import 'rooms_state.dart';

final class RoomsBloc extends Bloc<RoomsEvent, RoomsState> {
  RoomsBloc({required ProposalRepository repository, required UserId hostId})
      : _repository = repository,
        _hostId = hostId,
        super(const RoomsInitial()) {
    on<RoomsEvent>(
      (event, emit) => switch (event) {
        RoomsRequested() => _onRequested(emit),
        RoomCreated(:final name) => _onCreated(name, emit),
      },
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final ProposalRepository _repository;
  final UserId _hostId;

  Future<void> _onRequested(Emitter<RoomsState> emit) async {
    emit(const RoomsLoading());
    try {
      emit(RoomsLoaded(rooms: await _repository.loadRooms()));
    } on Exception {
      emit(const RoomsError());
    }
  }

  Future<void> _onCreated(String name, Emitter<RoomsState> emit) async {
    final rooms = _currentRooms;
    if (rooms == null) return;

    final outcome = checkRoomName(name: name);
    if (outcome case RuleInvalid(:final error)) {
      emit(RoomsLoaded(rooms: rooms, ruleError: error));
      return;
    }

    try {
      final room = await _repository.createRoom(
        name: name.trim(),
        hostId: _hostId,
      );
      emit(RoomsLoaded(rooms: [...rooms, room]));
    } on Exception {
      emit(const RoomsError());
    }
  }

  List<Room>? get _currentRooms => switch (state) {
        RoomsLoaded(:final rooms) => rooms,
        _ => null,
      };
}
