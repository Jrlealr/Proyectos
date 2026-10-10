import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/main.dart';

void main() {
  testWidgets('la app arranca', (tester) async {
    await tester.pumpWidget(const AppConductores());
    expect(find.text('App Conductores'), findsOneWidget);
  });
}
