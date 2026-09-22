import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/quick_add_template.dart';

Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick add',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Start with a common document type.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in quickAddTemplates)
                    ActionChip(
                      avatar: Icon(_iconForTemplate(template.icon)),
                      label: Text(template.label),
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/add?template=${template.id}');
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

IconData _iconForTemplate(String icon) {
  switch (icon) {
    case 'badge':
      return Icons.badge_outlined;
    case 'flight':
      return Icons.flight_outlined;
    case 'directions_car':
      return Icons.directions_car_outlined;
    case 'account_balance':
      return Icons.account_balance_outlined;
    case 'how_to_vote':
      return Icons.how_to_vote_outlined;
    default:
      return Icons.description_outlined;
  }
}
