import 'package:flutter_test/flutter_test.dart';
import 'package:emotion_companion/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const EmotionCompanionApp());
    expect(find.text('首页'), findsWidgets);
  });
}
