import 'package:flutter_test/flutter_test.dart';
import 'package:campus_hub/main.dart';

void main() {
  testWidgets("App launches test", (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const CampusHubApp());

    // Just check app loaded without crash
    expect(find.byType(CampusHubApp), findsOneWidget);
  });
}

