import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/presentation/export_backup_screen.dart';
import '../features/backup/presentation/import_backup_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/documents/presentation/document_detail_screen.dart';
import '../features/documents/presentation/document_form_screen.dart';
import '../features/documents/presentation/expiry_screen.dart';
import '../features/documents/presentation/library_screen.dart';
import '../features/people/presentation/people_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/privacy_policy_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/expiry',
              builder: (context, state) => const ExpiryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/people',
              builder: (context, state) => const PeopleScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings/export-backup',
      builder: (context, state) => const ExportBackupScreen(),
    ),
    GoRoute(
      path: '/settings/import-backup',
      builder: (context, state) => const ImportBackupScreen(),
    ),
    GoRoute(
      path: '/settings/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/settings/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) => DocumentFormScreen(
        templateId: state.uri.queryParameters['template'],
      ),
    ),
    GoRoute(
      path: '/document/:id',
      builder: (context, state) {
        return DocumentDetailScreen(id: state.pathParameters['id']!);
      },
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) {
            return DocumentFormScreen(
              documentId: state.pathParameters['id'],
            );
          },
        ),
      ],
    ),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Expiry',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
