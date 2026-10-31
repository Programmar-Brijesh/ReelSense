import 'package:shared_preferences/shared_preferences.dart';
import '../models/controller_state.dart';

class DashboardPreferencesService {
  static const String _keyMasterEnabled = 'key_master_controller_enabled';
  static const String _keyVoiceEnabled = 'key_voice_control_enabled';
  static const String _keyGestureEnabled = 'key_gesture_control_enabled';
  static const String _keySessionActive = 'key_reel_session_active';

  /// Loads saved dashboard controller preferences from SharedPreferences.
  Future<ControllerState> loadControllerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMasterEnabled = prefs.getBool(_keyMasterEnabled) ?? false;
      final isVoiceEnabled = prefs.getBool(_keyVoiceEnabled) ?? true;
      final isGestureEnabled = prefs.getBool(_keyGestureEnabled) ?? true;
      // Reel session should always start inactive on cold launch unless master is on
      final isSessionActive = isMasterEnabled
          ? (prefs.getBool(_keySessionActive) ?? false)
          : false;

      return ControllerState(
        isMasterEnabled: isMasterEnabled,
        isVoiceEnabled: isVoiceEnabled,
        isGestureEnabled: isGestureEnabled,
        isSessionActive: isSessionActive,
      );
    } catch (_) {
      return const ControllerState();
    }
  }

  /// Persists master controller toggle state.
  Future<bool> setMasterControllerEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyMasterEnabled, enabled);
      if (!enabled) {
        // Automatically stop session when master is stopped
        await prefs.setBool(_keySessionActive, false);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Persists voice control toggle state.
  Future<bool> setVoiceControlEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_keyVoiceEnabled, enabled);
    } catch (_) {
      return false;
    }
  }

  /// Persists gesture control toggle state.
  Future<bool> setGestureControlEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_keyGestureEnabled, enabled);
    } catch (_) {
      return false;
    }
  }

  /// Persists active Reel Session state.
  Future<bool> setReelSessionActive(bool active) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_keySessionActive, active);
    } catch (_) {
      return false;
    }
  }
}
