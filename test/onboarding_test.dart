import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reelsense/features/onboarding/services/onboarding_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingStorageService Tests', () {
    late OnboardingStorageService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = OnboardingStorageService();
    });

    test('Initial onboarding status is false', () async {
      final completed = await service.hasCompletedOnboarding();
      expect(completed, isFalse);
    });

    test('Marking onboarding complete persists true', () async {
      await service.setCompletedOnboarding(completed: true);
      final completed = await service.hasCompletedOnboarding();
      expect(completed, isTrue);
    });

    test('Resetting onboarding clears status to false', () async {
      await service.setCompletedOnboarding(completed: true);
      expect(await service.hasCompletedOnboarding(), isTrue);

      await service.resetOnboarding();
      expect(await service.hasCompletedOnboarding(), isFalse);
    });
  });
}
