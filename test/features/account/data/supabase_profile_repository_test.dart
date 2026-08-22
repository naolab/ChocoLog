import 'dart:math';

import 'package:chocolog/features/account/data/supabase_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('プロフィールDTOをSupabaseの列名から変換できる', () {
    final profile = SupabaseProfile.fromMap({
      'id': 'user-1',
      'public_id': 'CL-7K4P9Q',
      'display_name': 'なお',
      'updated_at': '2026-08-22T00:00:00Z',
    });

    expect(profile.id, 'user-1');
    expect(profile.publicId, 'CL-7K4P9Q');
    expect(profile.displayName, 'なお');
    expect(profile.updatedAt, isNotNull);
  });

  test('プレビュー用公開IDはCL-英数字6文字形式になる', () {
    final id = SupabaseProfileRepository.generatePreviewPublicId(
      _FixedRandom(),
    );

    expect(id, matches(RegExp(r'^CL-[A-Z0-9]{6}$')));
  });
}

class _FixedRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;
}
