import 'package:flutter_test/flutter_test.dart';
import 'package:cake_cost/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const CakeCostApp());
    // Приложение отрисовалось
    expect(find.byType(CakeCostApp), findsOneWidget);
  });
}
