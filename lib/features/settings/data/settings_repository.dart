import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppLockKey = 'app_lock_enabled';
const _kDocReminderShownKey = 'doc_upload_reminder_shown';
const _kThemeModeKey = 'theme_mode';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;
  final _auth = LocalAuthentication();

  bool get isAppLockEnabled => _prefs.getBool(_kAppLockKey) ?? false;

  Future<void> setAppLockEnabled(bool value) =>
      _prefs.setBool(_kAppLockKey, value);

  bool get isDocReminderShown =>
      _prefs.getBool(_kDocReminderShownKey) ?? false;
  Future<void> markDocReminderShown() =>
      _prefs.setBool(_kDocReminderShownKey, true);

  ThemeMode get themeMode {
    switch (_prefs.getString(_kThemeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _prefs.setString(_kThemeModeKey, value);
  }

  /// Returns true if the device can use biometric or device credential auth.
  Future<bool> canAuthenticate() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck || isSupported;
  }

  /// Prompts the OS authentication UI (biometric + device credential fallback).
  /// Returns true on success.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Docket to access your documents.',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
