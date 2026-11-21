// Ekran prijave: korisnicko ime + lozinka, greska na srpskom.
//
// Ciljana aplikacija stize kroz `app` (backoffice salje `backoffice`):
// server po njoj bira domensko pravilo `checkCanUseBackoffice` i isti kôd
// greske, a poruku bira ekran iz koda (`serverMessage`) — nalog namenjen
// mobilnoj aplikaciji odbija se RECIMA (`BackofficeNotAllowed`). Uspeh ne
// vodi nigde — cuvar ruta sam vraca prijavljenog na sobe
// (`refreshListenable` na AuthBloc strimu).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radioroom_blocs/radioroom_blocs.dart';
import 'package:radioroom_contract/radioroom_contract.dart';
import 'package:radioroom_ui/radioroom_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.app});

  /// Ciljana aplikacija prijave (backoffice salje `AppTarget.backoffice`).
  final AppTarget app;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _username.text.trim();
    if (username.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unesi korisničko ime i lozinku.'),
          ),
        );
      return;
    }
    context.read<AuthBloc>().add(
      LoginRequested(
        username: username,
        password: _password.text,
        app: widget.app,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, state) => state is AuthFailure,
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(serverMessage(state.reason))));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Prijava — moderacija')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Backoffice je za moderatore. Prijavi se nalogom moderatora.',
                  ),
                  const SizedBox(height: 16),
                  // Istekla prijava: ekran kaze zasto je korisnik ovde
                  // (ista poruka kao za `session_expired` sa servera).
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) => switch (state) {
                      Unauthenticated(expired: true) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          serverMessage(
                            const ApiError(code: ErrorCodes.sessionExpired),
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'Korisničko ime',
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Lozinka'),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (previous, next) =>
                        (previous is AuthLoading) != (next is AuthLoading),
                    builder: (context, state) {
                      if (state is AuthLoading) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return FilledButton(
                        onPressed: _submit,
                        child: const Text('Prijavi se'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Demo nalog: moderator / demo1234'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
