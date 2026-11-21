// Potvrda povlacenja svog predloga — povucen predlog se ne vraca.
//
// Posle potvrde ekran samo salje `ProposalWithdrawn`; da li je predlog
// tvoj i da li jos ceka ishod proverava domen u Bloc-u (`checkCanWithdraw`),
// a zatim i server.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';

Future<void> confirmWithdraw(BuildContext context, Proposal proposal) async {
  final bloc = context.read<ProposalListBloc>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Povući „${proposal.song.title}“?'),
      content: const Text(
        'Predlog izlazi iz sobe i ne broji se u tvoja 3 aktivna predloga.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Otkaži'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Povuci'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) bloc.add(ProposalWithdrawn(proposal.id));
}
