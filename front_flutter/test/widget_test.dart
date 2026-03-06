import 'package:flutter_test/flutter_test.dart';

import 'package:front_flutter/main.dart';

void main() {
  testWidgets('renders scanner title', (WidgetTester tester) async {
    await tester.pumpWidget(const StockManagerApp());

    expect(find.text('Kaki3D - Scanner NFC'), findsOneWidget);
  });
}
