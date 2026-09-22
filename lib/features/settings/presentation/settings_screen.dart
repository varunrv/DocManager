import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../backup/presentation/import_backup_screen.dart';
import '../../documents/presentation/document_providers.dart';
import '../../people/presentation/people_providers.dart';
import 'backup_password_dialog.dart';
import 'lock_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _backupBusy = false;

  Future<T> _runWithoutRelock<T>(Future<T> Function() action) async {
    final suspendCount = ref.read(lockSuspendCountProvider);
    ref.read(lockSuspendCountProvider.notifier).state = suspendCount + 1;
    try {
      return await action();
    } finally {
      final current = ref.read(lockSuspendCountProvider);
      ref.read(lockSuspendCountProvider.notifier).state =
          current > 0 ? current - 1 : 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleCount = ref.watch(peopleProvider).value?.length ?? 0;
    final docs = ref.watch(allDocumentsProvider);
    final storage = ref.watch(storageBytesProvider);
    final lockEnabled = ref.watch(appLockEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);

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
                subtitle: Text('${docs.value?.length ?? 0} saved'),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('People'),
                subtitle: Text(
                  '$peopleCount profile${peopleCount == 1 ? '' : 's'}',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.brightness_auto_outlined),
                      title: Text('Theme'),
                      subtitle: Text('Default follows your phone setting.'),
                    ),
                    const SizedBox(height: 4),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selected) {
                        _setThemeMode(ref, selected.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Security', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.enhanced_encryption_outlined),
                title: const Text('Encryption at rest'),
                subtitle: Text(
                  kIsWeb
                      ? 'Document files are encrypted in this browser. The key is stored locally in this browser profile.'
                      : 'Documents are encrypted on this device.',
                ),
              ),
            ),
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
            Text(
              'Backup & restore',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.upload_outlined),
                    title: const Text('Export backup'),
                    subtitle: const Text(
                      'Choose people, then their documents, then share an encrypted .docket file.',
                    ),
                    onTap: () => context.push('/settings/export-backup'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: _backupBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    title: const Text('Import backup'),
                    subtitle: const Text(
                      'Add documents from a backup without erasing your vault.',
                    ),
                    enabled: !_backupBusy,
                    onTap: _backupBusy ? null : _startImport,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Coming later', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_outlined),
                title: Text('Cloud sync'),
                subtitle:
                    Text('Not set up yet. Documents stay on this device.'),
              ),
            ),
            const SizedBox(height: 24),
            Text('About', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About Docket'),
                subtitle: Text(
                  kIsWeb
                      ? 'Version, privacy, and how files stay in this browser.'
                      : 'Version, privacy, and how files stay on this device.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/about'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startImport() async {
    final file = await _runWithoutRelock(
      () => FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['docket'],
      ),
    );
    if (file == null || !mounted) return;

    late final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 'Could not read the selected backup file.');
      }
      return;
    }
    if (!mounted) return;

    final password = await showBackupPasswordDialog(
      context,
      title: 'Import backup',
      confirm: false,
    );
    if (password == null || !mounted) return;

    setState(() => _backupBusy = true);
    try {
      final preview = await ref
          .read(vaultBackupServiceProvider)
          .previewImport(bytes, password);
      if (preview.people.isEmpty) {
        if (mounted) {
          showAppMessage(context, 'This backup has nothing to import.');
        }
        return;
      }
      ref.read(backupImportPreviewProvider.notifier).state = preview;
      ref.read(backupImportPasswordProvider.notifier).state = password;
      if (mounted) {
        context.push('/settings/import-backup');
      }
    } on AppException catch (error) {
      if (mounted) showAppMessage(context, error.message);
    } catch (_) {
      if (mounted) showAppMessage(context, 'Could not open backup.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _setThemeMode(WidgetRef ref, ThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    ref.read(themeModeProvider.notifier).state = mode;
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);

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
      final authenticated = await settingsRepo.authenticate();
      if (!authenticated) {
        if (context.mounted) {
          showAppMessage(
            context,
            'Authentication failed. App lock not enabled.',
          );
        }
        return;
      }
    }

    await settingsRepo.setAppLockEnabled(enable);
    if (enable) {
      await settingsRepo.markDocReminderShown();
    }
    ref.read(appLockEnabledProvider.notifier).state = enable;
    if (!enable) {
      ref.read(lockProvider.notifier).unlock();
    }
  }
}
