import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const LevelMaxingApp() as Widget);
  });
}

class LevelMaxingApp {
  const LevelMaxingApp();
}