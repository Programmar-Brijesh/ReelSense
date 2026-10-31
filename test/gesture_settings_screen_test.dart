import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelsense/features/gestures/models/gesture_mapping.dart';
import 'package:reelsense/features/gestures/screens/gesture_settings_screen.dart';
import 'package:reelsense/features/gestures/services/gesture_platform_service.dart';

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

  testWidgets('GestureSettingsScreen renders default gestures and safety info', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: GestureSettingsScreen(
          platformService: GesturePlatformService(channel: channel, eventChannel: eventChannel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hand Gesture Control'), findsOneWidget);
    expect(find.text('Front Camera Tracking Ready'), findsOneWidget);
    expect(find.text('Configured Gestures'), findsOneWidget);

    // Verify all 4 default gestures are present
    for (final gesture in ReelGesture.values) {
      expect(find.text(gesture.displayName), findsOneWidget);
      expect(find.text(gesture.action), findsOneWidget);
    }

    // Verify custom gestures UI is completely absent
    expect(find.text('Custom Hand Gestures'), findsNothing);
    expect(find.text('Register'), findsNothing);
  });
}
