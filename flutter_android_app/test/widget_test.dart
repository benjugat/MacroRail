import 'package:flutter_test/flutter_test.dart';
import 'package:macro_rail_test/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroRailApp());
    expect(find.text('Macro Rail Test'), findsOneWidget);
  });
}
