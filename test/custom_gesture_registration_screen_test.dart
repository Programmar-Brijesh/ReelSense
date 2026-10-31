import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsense/features/commands/models/reel_action.dart';
import 'package:reelsense/features/gestures/screens/custom_gesture_registration_screen.dart';
import 'package:reelsense/features/gestures/services/gesture_platform_service.dart';
import 'gesture_settings_screen_test.dart';

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
          case 'startGestureRegistration':
            return true;
          case 'stopGestureRegistration':
            return true;
          case 'syncCustomGestures':
            return true;
          case 'validateGestureConflict':
            return {'hasConflict': false};
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

  testWidgets('CustomGestureRegistrationScreen renders action selection and transitions to capture', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeCustomGestureRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomGestureRegistrationScreen(
          repository: repo,
          platformService: GesturePlatformService(channel: channel, eventChannel: eventChannel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1: Select Action'), findsOneWidget);
    expect(find.text('Choose Instagram Action'), findsOneWidget);

    for (final action in ReelAction.values) {
      expect(find.text(action.displayName), findsOneWidget);
    }

    // Tap Replay Reel
    await tester.tap(find.text('Replay Reel'));
    await tester.pumpAndSettle();

    // Tap Continue
    await tester.tap(find.text('Continue to Camera Capture'));
    await tester.pumpAndSettle();

    // Now in Step 2: Capture Hand Pose
    expect(find.text('Step 2: Capture Hand Pose'), findsOneWidget);
    expect(find.text('Replay Reel'), findsOneWidget);
    expect(find.text('Show Hand to Camera'), findsOneWidget);
    expect(find.text('Start Hand Capture'), findsOneWidget);
  });
}
