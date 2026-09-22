import 'package:flutter/material.dart';

import '../../../app/widgets/constrained_page_body.dart';
import '../domain/app_privacy.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ConstrainedPageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Last updated: ${AppPrivacy.lastUpdated}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(AppPrivacy.summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            for (final section in AppPrivacy.sections) ...[
              Text(section.$1, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(section.$2, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
