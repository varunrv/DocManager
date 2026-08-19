import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppLockKey = 'app_lock_enabled';
const _kDocReminderShownKey = 'doc_upload_reminder_shown';

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
        localizedReason: 'Unlock Document Manager to access your documents.',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
