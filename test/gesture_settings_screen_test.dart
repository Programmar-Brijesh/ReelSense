import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsense/features/commands/models/reel_action.dart';
import 'package:reelsense/features/gestures/data/custom_gesture_repository.dart';
import 'package:reelsense/features/gestures/models/custom_gesture.dart';
import 'package:reelsense/features/gestures/models/gesture_mapping.dart';
import 'package:reelsense/features/gestures/screens/gesture_settings_screen.dart';
import 'package:reelsense/features/gestures/services/gesture_platform_service.dart';

class FakeCustomGestureRepository implements CustomGestureRepository {
  final List<CustomGesture> gestures;
  FakeCustomGestureRepository([List<CustomGesture>? initial]) : gestures = initial ?? [];

  @override
  Future<List<CustomGesture>> getAllGestures() async => List.unmodifiable(gestures);

  @override
  Future<List<CustomGesture>> getEnabledGestures() async =>
      gestures.where((g) => g.isEnabled).toList();

  @override
  Future<CustomGesture?> getGestureById(String id) async =>
      gestures.cast<CustomGesture?>().firstWhere((g) => g?.id == id, orElse: () => null);

  @override
  Future<int> createGesture(CustomGesture gesture) async {
    gestures.add(gesture);
    return 1;
  }

  @override
  Future<int> updateGesture(CustomGesture gesture) async {
    final idx = gestures.indexWhere((g) => g.id == gesture.id);
    if (idx >= 0) gestures[idx] = gesture;
    return 1;
  }

  @override
  Future<int> deleteGesture(String id) async {
    gestures.removeWhere((g) => g.id == id);
    return 1;
  }

  @override
  Future<int> updateGestureStatus(String id, bool isEnabled) async {
    final idx = gestures.indexWhere((g) => g.id == id);
    if (idx >= 0) gestures[idx] = gestures[idx].copyWith(isEnabled: isEnabled);
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('in.developerbrijesh.reelsense/gestures');
  const EventChannel eventChannel = EventChannel('in.developerbrijesh.reelsense/gesture_events');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'hasCameraPermission':
            return true;
          case 'isFrontCameraAvailable':
            return true;
          case 'requestCameraPermission':
            return true;
          case 'syncCustomGestures':
            return true;
          default:
            return null;
        }
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {},
        onCancel: (arguments) {},
      ),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('GestureSettingsScreen renders default gestures, custom gestures section, and register button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeCustomGestureRepository([
      CustomGesture(
        id: 'cg_1',
        name: 'Three Fingers',
        action: ReelAction.replayReel,
        landmarkTemplateJson: '[]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: GestureSettingsScreen(
          customGestureRepository: repo,
          platformService: GesturePlatformService(channel: channel, eventChannel: eventChannel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hand Gesture Control'), findsOneWidget);
    expect(find.text('Front Camera Tracking Ready'), findsOneWidget);
    expect(find.text('Configured Gestures'), findsOneWidget);

    // Verify 4 default gestures
    for (final gesture in ReelGesture.values) {
      expect(find.text(gesture.displayName), findsOneWidget);
      expect(find.text(gesture.action), findsOneWidget);
    }

    // Verify custom gestures section
    expect(find.text('Custom Hand Gestures'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Three Fingers'), findsOneWidget);
    expect(find.text('Replay Reel'), findsOneWidget);
  });
}
