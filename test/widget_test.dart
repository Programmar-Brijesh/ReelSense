import 'package:flutter_test/flutter_test.dart';
import 'package:reelsense/main.dart';
import 'package:reelsense/features/splash/screens/splash_screen.dart';

void main() {
  testWidgets('App launches with SplashScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Expect SplashScreen to be mounted
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
