import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../widgets/pattern_background.dart';

Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null && uri.hasScheme) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false;
    }
  }
  if (!opened) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the link.')));
  }
}

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PatternScaffold(
      appBar: AppBar(title: const Text('Support Kinktionary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.favorite_outline,
              size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Keep the glossary free',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Kinktionary is free, open source and has no ads or trackers. '
                'Donations are optional and help cover hosting, moderation '
                'and the time spent researching and writing definitions.\n\n'
                'Donating does not unlock features or change how your account '
                'works. Donations are handled by an external payment page, so '
                'this app never sees your payment details.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (donationUrl.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.schedule),
                title: Text('Donation page coming soon'),
                subtitle: Text('Thank you for wanting to help.'),
              ),
            )
          else
            FilledButton.icon(
              onPressed: () => openExternal(context, donationUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open donation page'),
            ),
        ],
      ),
    );
  }
}
