import 'package:shared_preferences/shared_preferences.dart';
import '../../recognition/models/recognition_mode.dart';
import '../models/auto_start_config.dart';

class AutoStartPreferenceService {
  static const String keyAutoStartEnabled = 'reelsense_auto_start_enabled';
  static const String keyControllerMode = 'reelsense_auto_start_controller_mode';
  static const String keyRecognitionMode = 'reelsense_auto_start_recognition_mode';
  static const String keyLocale = 'reelsense_auto_start_locale';
  static const String keySetupCompleted = 'reelsense_auto_start_setup_completed';
  static const String keyUpdatedAt = 'reelsense_auto_start_updated_at';

  final SharedPreferences? customPrefs;

  AutoStartPreferenceService({this.customPrefs});

  Future<SharedPreferences> _getPrefs() async {
    return customPrefs ?? await SharedPreferences.getInstance();
  }

  /// Loads full saved Auto-Start configuration.
  Future<AutoStartConfig> loadConfig() async {
    final prefs = await _getPrefs();
    final isEnabled = prefs.getBool(keyAutoStartEnabled) ?? false;
    final modeStr = prefs.getString(keyControllerMode) ?? 'voice';
    final recModeStr = prefs.getString(keyRecognitionMode) ?? 'offline';
    final locale = prefs.getString(keyLocale) ?? 'en-US';
    final setupCompleted = prefs.getBool(keySetupCompleted) ?? false;
    final updatedAt = prefs.getInt(keyUpdatedAt) ?? DateTime.now().millisecondsSinceEpoch;

    return AutoStartConfig(
      isEnabled: isEnabled,
      controllerMode: AutoStartControllerMode.fromKey(modeStr),
      recognitionMode: RecognitionMode.fromKey(recModeStr) ?? RecognitionMode.offline,
      locale: locale,
      hasCompletedSetup: setupCompleted,
      updatedAt: updatedAt,
    );
  }

  /// Saves full Auto-Start configuration.
  Future<void> saveConfig(AutoStartConfig config) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyAutoStartEnabled, config.isEnabled);
    await prefs.setString(keyControllerMode, config.controllerMode.key);
    await prefs.setString(keyRecognitionMode, config.recognitionMode.key);
    await prefs.setString(keyLocale, config.locale);
    await prefs.setBool(keySetupCompleted, config.hasCompletedSetup);
    await prefs.setInt(keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Toggles Auto-Start enabled state.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyAutoStartEnabled, enabled);
    await prefs.setInt(keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Updates preferred controller mode (voice or gesture).
  Future<void> setControllerMode(AutoStartControllerMode mode) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyControllerMode, mode.key);
    await prefs.setInt(keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Updates setup completed state.
  Future<void> setSetupCompleted(bool completed) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keySetupCompleted, completed);
  }

  /// Checks if Auto-Start is currently enabled.
  Future<bool> isEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(keyAutoStartEnabled) ?? false;
  }
}
