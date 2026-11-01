// Potvrda glasa — zajednicka za listu i detalj predloga.
//
// Glas je nepovratan (jedan glas po rundi), pa trazi potvrdu u dijalogu.
// Posle potvrde ekran samo salje `VoteCast`; vazenje glasa proverava domen
// u Bloc-u.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

Future<void> confirmVote(BuildContext context, Proposal proposal) async {
  final bloc = context.read<ProposalListBloc>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Glasati za „${proposal.song.title}“?'),
      content: const Text('Glas u rundi se ne može promeniti.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Otkaži'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Glasaj'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) bloc.add(VoteCast(proposal.id));
}
