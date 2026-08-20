import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// True when the user has successfully authenticated this session.
/// Starts as false so the lock screen is shown immediately if lock is enabled.
class LockNotifier extends Notifier<bool> {
  @override
  bool build() {
    final settings = ref.watch(settingsRepositoryProvider);
    // If lock is disabled, treat the app as already unlocked.
    return !settings.isAppLockEnabled;
  }

  void unlock() => state = true;

  /// Called when the app goes to background — re-engages the lock.
  void lock() {
    final settings = ref.read(settingsRepositoryProvider);
    if (settings.isAppLockEnabled) state = false;
  }
}

final lockProvider = NotifierProvider<LockNotifier, bool>(LockNotifier.new);

/// Exposed so Settings screen can read and toggle without importing the repo.
final appLockEnabledProvider = StateProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).isAppLockEnabled;
});

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ref.watch(settingsRepositoryProvider).themeMode;
});

/// Counts in-flight external platform flows like file pickers or camera apps.
/// While this is non-zero, app backgrounding should not trigger a relock.
final lockSuspendCountProvider = StateProvider<int>((ref) => 0);
