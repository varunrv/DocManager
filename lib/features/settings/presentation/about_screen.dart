import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/widgets/constrained_page_body.dart';
import '../domain/app_privacy.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider);
    final theme = Theme.of(context);
    final packageInfo = info.value;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ConstrainedPageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_special_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Docket',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      packageInfo == null
                          ? 'Version…'
                          : 'Version ${packageInfo.version} (${packageInfo.buildNumber})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Local-first document vault for you and your family.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Privacy', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phonelink_lock_outlined),
                    title: const Text('Local only'),
                    subtitle: Text(
                      kIsWeb
                          ? 'Files stay in this browser profile unless you export or share them.'
                          : 'Files stay on this device unless you export or share them.',
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.enhanced_encryption_outlined),
                    title: Text('Encrypted files'),
                    subtitle: Text(
                      'Document contents are encrypted at rest on this device.',
                    ),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('No Docket cloud account'),
                    subtitle: Text(
                      'We do not upload your vault to our servers.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined),
                    title: const Text('Privacy policy'),
                    subtitle:
                        const Text('Full details about data on this device'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/privacy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppPrivacy.summary,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Package ${packageInfo?.packageName ?? 'com.varun.docket'}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
