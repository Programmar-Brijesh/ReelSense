import 'package:shared_preferences/shared_preferences.dart';
import '../models/recognition_mode.dart';

class RecognitionPreferenceService {
  static const String keyMode = 'reelsense_recognition_mode';
  static const String keyLocale = 'reelsense_recognition_locale';
  static const String keyUpdatedAt = 'reelsense_recognition_updated_at';
  static const String keyInitialSetupDone = 'reelsense_recognition_initial_setup_done';

  static const String defaultLocale = 'en-US';

  final SharedPreferences? customPrefs;

  RecognitionPreferenceService({this.customPrefs});

  Future<SharedPreferences> _getPrefs() async {
    return customPrefs ?? await SharedPreferences.getInstance();
  }

  /// Gets the currently selected recognition mode, or null if initial setup has not been completed.
  Future<RecognitionMode?> getSelectedMode() async {
    final prefs = await _getPrefs();
    final modeStr = prefs.getString(keyMode);
    return RecognitionMode.fromKey(modeStr);
  }

  /// Permanently saves the selected recognition mode and records the update timestamp.
  Future<void> setSelectedMode(RecognitionMode mode) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyMode, mode.key);
    await prefs.setInt(keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(keyInitialSetupDone, true);
  }

  /// Gets the currently configured recognition locale (default 'en-US').
  Future<String> getSelectedLocale() async {
    final prefs = await _getPrefs();
    final locale = prefs.getString(keyLocale);
    return locale ?? defaultLocale;
  }

  /// Sets the recognition locale.
  Future<void> setSelectedLocale(String locale) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyLocale, locale);
    await prefs.setInt(keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Checks whether the user has completed the initial setup flow for voice recognition.
  Future<bool> isInitialSetupDone() async {
    final prefs = await _getPrefs();
    final done = prefs.getBool(keyInitialSetupDone);
    return done ?? false;
  }

  /// Sets whether the initial setup has been completed.
  Future<void> setInitialSetupDone(bool isDone) async {
    final prefs = await _getPrefs();
    await prefs.setBool(keyInitialSetupDone, isDone);
  }

  /// Gets the last timestamp when preferences were updated.
  Future<DateTime?> getPreferenceUpdatedAt() async {
    final prefs = await _getPrefs();
    final millis = prefs.getInt(keyUpdatedAt);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Clears stored recognition preferences (useful for testing or full app resets).
  Future<void> resetPreferences() async {
    final prefs = await _getPrefs();
    await prefs.remove(keyMode);
    await prefs.remove(keyLocale);
    await prefs.remove(keyUpdatedAt);
    await prefs.remove(keyInitialSetupDone);
  }
}
