import 'package:chocolog/core/widgets/chocolog_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('標準スピナーを使わず3ドットを表示する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ChocoLogLoadingIndicator())),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ChocoLogLoadingIndicator), findsOneWidget);
    expect(find.byType(Container), findsNWidgets(3));
  });
}
