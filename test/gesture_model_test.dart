import 'package:flutter_test/flutter_test.dart';
import 'package:reelsense/features/gestures/models/gesture_mapping.dart';

void main() {
  group('ReelGesture Model & Mapping Tests', () {
    test('All 4 defined gestures map to expected Instagram actions', () {
      expect(ReelGesture.openPalm.action, 'PAUSE_PLAY');
      expect(ReelGesture.thumbsUp.action, 'LIKE_REEL');
      expect(ReelGesture.indexFinger.action, 'NEXT_REEL');
      expect(ReelGesture.indexAndMiddle.action, 'PREVIOUS_REEL');
    });

    test('ReelGesture.fromId resolves correctly case-insensitively', () {
      expect(ReelGesture.fromId('OPEN_PALM'), ReelGesture.openPalm);
      expect(ReelGesture.fromId('thumbs_up'), ReelGesture.thumbsUp);
      expect(ReelGesture.fromId('INDEX_FINGER'), ReelGesture.indexFinger);
      expect(ReelGesture.fromId('index_and_middle'), ReelGesture.indexAndMiddle);
      expect(ReelGesture.fromId('UNKNOWN_GESTURE'), isNull);
    });

    test('All gestures have non-empty labels and descriptions', () {
      for (final g in ReelGesture.values) {
        expect(g.displayName.isNotEmpty, isTrue);
        expect(g.actionLabel.isNotEmpty, isTrue);
        expect(g.description.isNotEmpty, isTrue);
      }
    });
  });
}
