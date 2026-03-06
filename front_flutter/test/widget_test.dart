import 'package:flutter_test/flutter_test.dart';

import 'package:front_flutter/main.dart';

void main() {
  testWidgets('renders scan screen title', (WidgetTester tester) async {
    await tester.pumpWidget(const StockManagerApp());

    expect(find.text('Kaki3D - Scan NFC'), findsOneWidget);
  });
}
