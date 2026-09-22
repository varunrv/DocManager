import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/splash_gate.dart';
import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'core/storage/file_store.dart';
import 'features/settings/presentation/lock_providers.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final prefs = await SharedPreferences.getInstance();
  final plainStore = createFileStore();
  final db = AppDatabase();
  await initializeVaultStorage(
    prefs: prefs,
    db: db,
    plainStore: plainStore,
  );
  db.close();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const _AppRoot(),
    ),
  );
}

/// Thin wrapper that observes lifecycle and re-locks on background.
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final isSuspended = ref.read(lockSuspendCountProvider) > 0;
      if (isSuspended) return;
      ref.read(lockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashGate(child: DocManagerApp());
  }
}
