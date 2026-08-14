import 'package:chocolog/app/theme.dart';
import 'package:chocolog/features/studios/data/studio_repository.dart';
import 'package:chocolog/features/studios/presentation/studio_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const studio = StudioItem(
    id: '123',
    name: 'chocoZAP テスト店',
    address: '東京都テスト区1-2-3',
    access: 'テスト駅 徒歩1分',
    equipmentUnits: {},
  );

  testWidgets('店舗詳細からよく行く店舗に設定できる', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ChocoLogTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<bool>(
                  context: context,
                  builder: (_) => const StudioFavoriteSheet(
                    studio: studio,
                    favorite: false,
                  ),
                );
              },
              child: const Text('店舗名'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('店舗名'));
    await tester.pumpAndSettle();
    expect(find.text(studio.name), findsOneWidget);
    expect(find.text(studio.address), findsOneWidget);
    expect(find.text('よく行く店舗に設定'), findsOneWidget);

    await tester.tap(find.text('よく行く店舗に設定'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('設定済み店舗は詳細から解除できる', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ChocoLogTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<bool>(
                  context: context,
                  builder: (_) =>
                      const StudioFavoriteSheet(studio: studio, favorite: true),
                );
              },
              child: const Text('店舗名'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('店舗名'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('よく行く店舗から解除'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  test('選択状態の黄色はビビッドイエローに統一されている', () {
    expect(ChocoLogColors.softYellow, ChocoLogColors.yellow);
    expect(
      ChocoLogTheme.light.chipTheme.selectedColor,
      ChocoLogColors.softYellow,
    );
    expect(
      ChocoLogTheme.light.colorScheme.primaryContainer,
      ChocoLogColors.softYellow,
    );
  });
}
