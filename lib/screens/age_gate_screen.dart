import 'package:flutter/material.dart';

import '../data_store.dart';
import '../widgets/pattern_background.dart';

class AgeGateScreen extends StatelessWidget {
  final DataStore store;
  const AgeGateScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PatternScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Kinktionary',
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'A consent-first guide to kink terms, for the curious.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'This app discusses adult sexuality and is for people '
                        '18 and over. Content is educational and is not a '
                        'substitute for professional medical or mental-health '
                        'advice.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: store.confirmAge,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text("I'm 18 or older — continue"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Come back at 18'),
                        content: const Text(
                            'Kinktionary is only for adults. Thanks for being honest.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text("I'm under 18"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
