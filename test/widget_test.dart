import 'package:flutter_test/flutter_test.dart';
import 'package:thermal_print/main.dart';

void main() {
  testWidgets('Thermal Print app loads', (tester) async {
    await tester.pumpWidget(const ThermalPrintApp());
    expect(find.text('Thermal Print'), findsOneWidget);
  });
}
