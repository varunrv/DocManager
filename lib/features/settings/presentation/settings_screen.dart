import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../documents/presentation/document_providers.dart';
import '../../people/presentation/people_providers.dart';
import 'lock_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleCount = ref.watch(peopleProvider).valueOrNull?.length ?? 0;
    final docs = ref.watch(allDocumentsProvider);
    final storage = ref.watch(storageBytesProvider);
    final lockEnabled = ref.watch(appLockEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ConstrainedPageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Storage used'),
                subtitle: Text(
                  storage.when(
                    data: formatBytes,
                    loading: () => 'Calculating…',
                    error: (_, _) => 'Unavailable',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Documents'),
                subtitle: Text('${docs.valueOrNull?.length ?? 0} saved'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('People'),
                subtitle: Text(
                    '$peopleCount profile${peopleCount == 1 ? '' : 's'}'),
              ),
            ),
            const SizedBox(height: 24),
            Text('Security', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: const Text('App lock'),
                subtitle: const Text(
                  'Use your device biometrics, PIN, or pattern to open the app.',
                ),
                value: lockEnabled,
                onChanged: kIsWeb
                    ? null
                    : (value) => _toggleLock(context, ref, value),
              ),
            ),
            const SizedBox(height: 24),
            Text('Coming later', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_outlined),
                title: Text('Cloud sync'),
                subtitle: Text('Not set up yet. Documents stay on this device.'),
              ),
            ),
            const SizedBox(height: 24),
            Text('About', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Document Manager'),
                subtitle: Text(
                  kIsWeb
                      ? 'Files are stored in this browser. Clearing site data deletes the vault.'
                      : 'Files are stored only on this device.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);

    // When enabling, confirm the device can authenticate before saving.
    if (enable) {
      final canAuth = await settingsRepo.canAuthenticate();
      if (!canAuth) {
        if (context.mounted) {
          showAppMessage(
            context,
            'No screen lock set up on this device. '
            'Please add a PIN, pattern, or biometric in your device settings first.',
          );
        }
        return;
      }
      // Verify with one authentication before enabling.
      final authenticated = await settingsRepo.authenticate();
      if (!authenticated) {
        if (context.mounted) {
          showAppMessage(context, 'Authentication failed. App lock not enabled.');
        }
        return;
      }
    }

    await settingsRepo.setAppLockEnabled(enable);
    if (enable) {
      await settingsRepo.markDocReminderShown();
    }
    ref.read(appLockEnabledProvider.notifier).state = enable;
    // If disabling, immediately mark as unlocked so lock screen doesn't flash.
    if (!enable) {
      ref.read(lockProvider.notifier).unlock();
    }
  }
}
