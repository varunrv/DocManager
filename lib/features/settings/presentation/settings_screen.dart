import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/utils/formatters.dart';
import '../../documents/presentation/document_providers.dart';
import '../../people/presentation/people_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleCount = ref.watch(peopleProvider).valueOrNull?.length ?? 0;
    final docs = ref.watch(allDocumentsProvider);
    final storage = ref.watch(storageBytesProvider);

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
                subtitle: Text('$peopleCount profile${peopleCount == 1 ? '' : 's'}'),
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
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('App lock'),
                subtitle: Text('PIN and biometrics will be added in a later version.'),
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
}
