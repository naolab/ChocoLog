import 'package:chocolog/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ホームから通常4タブへ移動できる', (tester) async {
    await tester.pumpWidget(const ChocoLogApp());
    await tester.pumpAndSettle();

    expect(find.text('トレーニングを始める'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('トレーニングを始める'));
    await tester.pumpAndSettle();
    expect(find.text('今回の店舗'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(find.text('トレーニングの記録がここに表示されます'), findsOneWidget);

    await tester.tap(find.text('レポート'));
    await tester.pumpAndSettle();
    expect(find.text('記録を続けると週・月の成果を確認できます'), findsOneWidget);

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('目標回数や通知を設定できます'), findsOneWidget);
  });
}
