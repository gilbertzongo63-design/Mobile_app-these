import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/app.dart';

void main() {
  testWidgets('App bootstrap screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const WasteSortingMobileApp());
    await tester.pump();

    expect(find.text('EcoSort'), findsOneWidget);
    expect(find.textContaining('Bienvenue'), findsOneWidget);
    expect(find.text("Commencer l'analyse"), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Tips'), findsOneWidget);
  });
}
