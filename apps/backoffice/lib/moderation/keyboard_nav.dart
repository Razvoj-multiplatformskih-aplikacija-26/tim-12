// Tastatura ekrana moderacije: strelice selektuju, Delete uklanja, Esc izlazi.
//
// Omotac drzi `autofocus` da tasteri rade odmah po ulazu, bez klika misem.
// Brisanje slusa i Backspace: taster koji na Mac tastaturi pise Delete
// Flutter vidi kao Backspace (Delete je tek Fn+taj taster).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

class KeyboardNav extends StatelessWidget {
  const KeyboardNav({
    super.key,
    required this.proposals,
    required this.selectedId,
    required this.onSelect,
    required this.onRemove,
    required this.onEscape,
    required this.child,
  });

  final List<Proposal> proposals;
  final ProposalId? selectedId;
  final ValueChanged<ProposalId> onSelect;
  final ValueChanged<ProposalId> onRemove;
  final VoidCallback onEscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.delete): _RemoveIntent(),
        // Mac: taster sa oznakom Delete salje Backspace.
        SingleActivator(LogicalKeyboardKey.backspace): _RemoveIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _EscapeIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) => _move(intent.delta),
          ),
          _RemoveIntent: CallbackAction<_RemoveIntent>(
            onInvoke: (_) {
              final id = selectedId;
              if (id != null) onRemove(id);
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              onEscape();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  void _move(int delta) {
    if (proposals.isEmpty) return;
    final current = proposals.indexWhere((p) => p.id == selectedId);
    final next = (current < 0 ? 0 : (current + delta + proposals.length)) %
        proposals.length;
    onSelect(proposals[next].id);
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);

  final int delta;
}

class _RemoveIntent extends Intent {
  const _RemoveIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}
