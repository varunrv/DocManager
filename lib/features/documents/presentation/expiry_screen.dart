import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../domain/document_list_item.dart';
import 'document_providers.dart';

class ExpiryScreen extends ConsumerWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(expiryDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expiry')),
      body: ConstrainedPageBody(
        child: documents.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyExpiry();
            }

            final buckets = _bucketItems(items);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final bucket in buckets) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      bucket.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final item in bucket.items)
                    _ExpiryTile(item: item),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExpiryBucket {
  const _ExpiryBucket({required this.title, required this.items});

  final String title;
  final List<DocumentListItem> items;
}

List<_ExpiryBucket> _bucketItems(List<DocumentListItem> items) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final soonCutoff = todayDate.add(const Duration(days: 30));

  final expired = <DocumentListItem>[];
  final soon = <DocumentListItem>[];
  final upcoming = <DocumentListItem>[];

  for (final item in items) {
    final expiresAt = item.document.expiresAt;
    if (expiresAt == null) continue;
    final expiryDate =
        DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    if (expiryDate.isBefore(todayDate)) {
      expired.add(item);
    } else if (!expiryDate.isAfter(soonCutoff)) {
      soon.add(item);
    } else {
      upcoming.add(item);
    }
  }

  int compare(DocumentListItem a, DocumentListItem b) {
    final aDate = a.document.expiresAt!;
    final bDate = b.document.expiresAt!;
    return aDate.compareTo(bDate);
  }

  expired.sort(compare);
  soon.sort(compare);
  upcoming.sort(compare);

  return [
    if (expired.isNotEmpty)
      _ExpiryBucket(title: 'Expired', items: expired),
    if (soon.isNotEmpty)
      _ExpiryBucket(title: 'Expiring soon', items: soon),
    if (upcoming.isNotEmpty)
      _ExpiryBucket(title: 'Upcoming', items: upcoming),
  ];
}

class _ExpiryTile extends ConsumerStatefulWidget {
  const _ExpiryTile({required this.item});

  final DocumentListItem item;

  @override
  ConsumerState<_ExpiryTile> createState() => _ExpiryTileState();
}

class _ExpiryTileState extends ConsumerState<_ExpiryTile> {
  var _saving = false;

  String _daysLabel(DateTime expiresAt) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expiryDate =
        DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final days = expiryDate.difference(todayDate).inDays;
    if (days < 0) {
      final overdue = -days;
      return overdue == 1 ? '1 day overdue' : '$overdue days overdue';
    }
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'In $days days';
  }

  Future<void> _toggleReminder(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(documentRepositoryProvider)
          .updateReminderEnabled(widget.item.document.id, value);
      if (!mounted) return;
      if (value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder saved. Notifications are coming soon.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update reminder.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.item.document;
    final expiresAt = document.expiresAt!;
    final personLabel = widget.item.person.isSelf
        ? widget.item.person.displayName
        : widget.item.person.ownerLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(document.title),
            subtitle: Text(
              '$personLabel · ${formatDate(expiresAt)} · ${_daysLabel(expiresAt)}',
            ),
            onTap: () => context.push('/document/${document.id}'),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            title: const Text('Reminder'),
            subtitle: const Text('Coming soon — saved for when notifications ship'),
            value: document.reminderEnabled,
            onChanged: _saving ? null : _toggleReminder,
          ),
        ],
      ),
    );
  }
}

class _EmptyExpiry extends StatelessWidget {
  const _EmptyExpiry();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No expiry dates yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add an expiry date when saving passports, licenses, or policies to track them here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
