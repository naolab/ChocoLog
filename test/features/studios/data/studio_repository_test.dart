import 'dart:convert';

import 'package:chocolog/features/studios/data/studio_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('店舗APIの器具IDをアプリ内器具と台数へ変換できる', () {
    final studios = jsonEncode({
      'list': [
        {
          'hacomono_studio_id': 123,
          'name': 'テスト店',
          'address': '東京都テスト区',
          'access': 'テスト駅 徒歩1分',
          'machines': [
            {
              'machine_details': {'module_id': 994},
              'total_units': 2,
            },
            {
              'machine_details': {'module_id': 985},
              'total_units': 4,
            },
            {
              'machine_details': {'module_id': 999999},
              'total_units': 1,
            },
          ],
        },
      ],
    });
    final machines = jsonEncode({
      'list': [
        {'topics_id': 994, 'name': 'チェストプレス'},
        {'topics_id': 985, 'name': 'トレッドミル'},
        {'topics_id': 999999, 'name': '未対応器具'},
      ],
    });

    final studio = parseStudioCatalog(studios, machines).single;

    expect(studio.id, '123');
    expect(studio.name, 'テスト店');
    expect(studio.equipmentUnits, {'chest-press': 2, 'treadmill': 4});
  });

  test('キャッシュ用JSONを往復できる', () {
    const original = StudioItem(
      id: '123',
      name: 'テスト店',
      address: '東京都テスト区',
      access: 'テスト駅 徒歩1分',
      equipmentUnits: {'bike': 3},
    );

    final restored = StudioItem.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.equipmentUnits, original.equipmentUnits);
  });
}
