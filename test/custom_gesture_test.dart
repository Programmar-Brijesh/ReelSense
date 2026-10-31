import 'package:flutter_test/flutter_test.dart';
import 'package:reelsense/features/commands/models/reel_action.dart';
import 'package:reelsense/features/gestures/models/custom_gesture.dart';

void main() {
  group('CustomGesture Model Tests', () {
    test('toMap and fromMap preserves all fields', () {
      final now = DateTime.now();
      const templateJson = '[{"x":0.1,"y":0.2,"z":0.3},{"x":0.4,"y":0.5,"z":0.6}]';

      final gesture = CustomGesture(
        id: 'test_123',
        name: 'Three Fingers',
        action: ReelAction.replayReel,
        landmarkTemplateJson: templateJson,
        sampleCount: 25,
        confidenceThreshold: 0.85,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = gesture.toMap();
      final fromMap = CustomGesture.fromMap(map);

      expect(fromMap.id, 'test_123');
      expect(fromMap.name, 'Three Fingers');
      expect(fromMap.action, ReelAction.replayReel);
      expect(fromMap.landmarkTemplateJson, templateJson);
      expect(fromMap.sampleCount, 25);
      expect(fromMap.confidenceThreshold, 0.85);
      expect(fromMap.isEnabled, isTrue);
      expect(fromMap.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('parsedLandmarks decodes valid JSON correctly', () {
      final now = DateTime.now();
      const templateJson = '[{"x":0.1,"y":0.2,"z":0.3}]';

      final gesture = CustomGesture(
        id: 'test_1',
        name: 'Peace',
        action: ReelAction.likeReel,
        landmarkTemplateJson: templateJson,
        createdAt: now,
        updatedAt: now,
      );

      final points = gesture.parsedLandmarks;
      expect(points.length, 1);
      expect(points[0]['x'], 0.1);
      expect(points[0]['y'], 0.2);
      expect(points[0]['z'], 0.3);
    });

    test('copyWith modifies only target fields', () {
      final now = DateTime.now();
      final gesture = CustomGesture(
        id: 'test_1',
        name: 'Peace',
        action: ReelAction.nextReel,
        landmarkTemplateJson: '[]',
        createdAt: now,
        updatedAt: now,
      );

      final updated = gesture.copyWith(
        name: 'Victory Sign',
        action: ReelAction.pausePlay,
        isEnabled: false,
      );

      expect(updated.id, 'test_1');
      expect(updated.name, 'Victory Sign');
      expect(updated.action, ReelAction.pausePlay);
      expect(updated.isEnabled, isFalse);
    });
  });
}
