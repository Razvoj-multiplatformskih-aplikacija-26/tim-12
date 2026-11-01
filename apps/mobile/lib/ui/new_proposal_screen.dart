// Forma novog predloga (KT1 §1: forma sa pravilom proverenim pri unosu).
//
// Pravila se NE pisu ovde: forma pri svakoj izmeni zove pravila iz domena
// (`checkNotRecentlyPlayed`, `checkMaxActiveProposals`), a tekst poruke
// bira `ruleMessage` iz `radioroom_ui` — isti izvor kao SnackBar sobe.
// Promena pravila u domenu (rok, limit) automatski menja i formu.
//
// Dva sloja: forma proverava radi korisnika (poruka odmah, dugme ugaseno),
// a Bloc proverava ponovo pre poziva porta, kao cuvar. Posle slanja forma
// ceka sledece stanje Bloc-a: uspeh ili tehnicka greska → nazad na listu;
// prekrsaj pravila → ostaje na formi (poruku prikazuje SnackBar sobe).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_domain/radioroom_domain.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

import '../paths.dart';
import 'room_error_view.dart';

class NewProposalScreen extends StatefulWidget {
  const NewProposalScreen({
    super.key,
    required this.currentUser,
    this.clock = DateTime.now,
  });

  /// Tekuci korisnik (u KT1 fiksan; u KT2 ga daje prijava).
  final UserId currentUser;

  /// "Sad" za pravilo nedavno pustene pesme.
  final DateTime Function() clock;

  @override
  State<NewProposalScreen> createState() => _NewProposalScreenState();
}

class _NewProposalScreenState extends State<NewProposalScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _link = TextEditingController();

  /// Poruka "Obavezno polje" tek kad je korisnik dirao polje.
  var _titleTouched = false;
  var _artistTouched = false;

  /// Predlog je poslat; forma ceka sledece stanje Bloc-a.
  var _submitting = false;

  /// Soba za koju je predlog poslat — povratak posle odgovora (stanje
  /// greske ne nosi snimak sobe).
  RoomId? _roomId;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Predloži pesmu')),
    body: BlocConsumer<ProposalListBloc, ProposalListState>(
      listenWhen: (_, _) => _submitting,
      listener: _onResult,
      builder: (context, state) => switch (state) {
        ProposalsInitial() ||
        ProposalsLoading() => const Center(child: CircularProgressIndicator()),
        ProposalsError() => const RoomErrorView(),
        ProposalsLoaded(:final snapshot) ||
        ProposalsEmpty(:final snapshot) => _form(context, snapshot),
      },
    ),
  );

  /// Prvo stanje Bloc-a posle slanja.
  void _onResult(BuildContext context, ProposalListState state) {
    if (state is ProposalsLoaded && state.ruleError != null) {
      setState(() => _submitting = false);
      return;
    }
    // Uspeh → lista sa novim predlogom; tehnicka greska → lista sa
    // ekranom greske i "Pokusaj ponovo".
    context.go(roomPath(_roomId!));
  }

  Widget _form(BuildContext context, RoomSnapshot snapshot) {
    final title = _title.text.trim();
    final artist = _artist.text.trim();

    // Pravila iz domena — forma samo cita ishod.
    final limitError = checkMaxActiveProposals(
      proposals: snapshot.proposals,
      userId: widget.currentUser,
    ).error;
    final recentError = title.isEmpty || artist.isEmpty
        ? null
        : checkNotRecentlyPlayed(
            song: Song(title: title, artist: artist),
            played: snapshot.proposals,
            now: widget.clock(),
          ).error;

    final canSubmit =
        !_submitting &&
        title.isNotEmpty &&
        artist.isNotEmpty &&
        limitError == null &&
        recentError == null;

    return ListView(
      padding: const EdgeInsets.all(Spacing.l),
      children: [
        if (limitError != null) ...[
          _RuleBanner(message: ruleMessage(limitError)),
          const SizedBox(height: Spacing.l),
        ],
        TextField(
          controller: _title,
          enabled: !_submitting,
          autofocus: limitError == null,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _titleTouched = true),
          decoration: InputDecoration(
            labelText: 'Naslov',
            border: const OutlineInputBorder(),
            errorMaxLines: 3,
            errorText: _titleTouched && title.isEmpty
                ? 'Obavezno polje'
                : recentError != null
                ? ruleMessage(recentError)
                : null,
          ),
        ),
        const SizedBox(height: Spacing.l),
        TextField(
          controller: _artist,
          enabled: !_submitting,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _artistTouched = true),
          decoration: InputDecoration(
            labelText: 'Izvođač',
            border: const OutlineInputBorder(),
            errorText: _artistTouched && artist.isEmpty
                ? 'Obavezno polje'
                : null,
          ),
        ),
        const SizedBox(height: Spacing.l),
        TextField(
          controller: _link,
          enabled: !_submitting,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Link (opciono)',
            helperText: 'npr. YouTube adresa pesme',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (canSubmit) _submit(snapshot.room.id, title, artist);
          },
        ),
        const SizedBox(height: Spacing.xl),
        FilledButton.icon(
          onPressed: canSubmit
              ? () => _submit(snapshot.room.id, title, artist)
              : null,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Predloži'),
        ),
      ],
    );
  }

  void _submit(RoomId roomId, String title, String artist) {
    final link = _link.text.trim();
    setState(() {
      _submitting = true;
      _roomId = roomId;
    });
    context.read<ProposalListBloc>().add(
      ProposalAdded(
        Song(
          title: title,
          artist: artist,
          externalLink: link.isEmpty ? null : link,
        ),
      ),
    );
  }
}

/// Prekrsaj pravila koji ne zavisi od unosa (npr. limit aktivnih predloga).
class _RuleBanner extends StatelessWidget {
  const _RuleBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.m),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.block, color: scheme.onErrorContainer),
          const SizedBox(width: Spacing.m),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
