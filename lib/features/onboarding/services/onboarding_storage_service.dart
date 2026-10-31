import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStorageService {
  static const String _keyHasCompletedOnboarding = 'has_completed_onboarding';

  /// Checks if the user has already completed the onboarding flow.
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyHasCompletedOnboarding) ?? false;
    } catch (_) {
      // Safely default to false on read failure to ensure onboarding is accessible
      return false;
    }
  }

  /// Sets whether the user has completed the onboarding flow.
  Future<bool> setCompletedOnboarding({bool completed = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_keyHasCompletedOnboarding, completed);
    } catch (_) {
      return false;
    }
  }

  /// Clears the onboarding completion flag (useful for testing and reset flows).
  Future<bool> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keyHasCompletedOnboarding);
    } catch (_) {
      return false;
    }
  }
}
