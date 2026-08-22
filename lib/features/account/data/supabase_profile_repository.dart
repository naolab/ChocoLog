import 'dart:math';

import 'package:chocolog/core/supabase/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProfileRepositoryProvider = Provider<SupabaseProfileRepository>(
  (ref) => SupabaseProfileRepository(),
);

class SupabaseProfile {
  const SupabaseProfile({
    required this.id,
    required this.publicId,
    required this.displayName,
    this.updatedAt,
  });

  final String id;
  final String publicId;
  final String displayName;
  final DateTime? updatedAt;

  factory SupabaseProfile.fromMap(Map<String, dynamic> map) {
    return SupabaseProfile(
      id: map['id'] as String,
      publicId: map['public_id'] as String,
      displayName: map['display_name'] as String,
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
    );
  }
}

class SupabaseProfileRepository {
  SupabaseClient get _client =>
      SupabaseService.client ??
      (throw StateError('Supabase has not been initialized'));

  User? get currentUser => _client.auth.currentUser;

  Future<SupabaseProfile?> currentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client
        .from('profiles')
        .select('id, public_id, display_name, updated_at')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return SupabaseProfile.fromMap(row);
  }

  Future<SupabaseProfile> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) throw StateError('ログインが必要です');
    final normalized = displayName.trim();
    if (normalized.isEmpty) throw ArgumentError('表示名を入力してください');
    if (normalized.length > 30) throw ArgumentError('表示名は30文字以内で入力してください');

    final row = await _client
        .from('profiles')
        .update({'display_name': normalized})
        .eq('id', user.id)
        .select('id, public_id, display_name, updated_at')
        .single();
    return SupabaseProfile.fromMap(row);
  }

  /// Used only by tests and local preview tooling to validate the public ID
  /// format without requiring a Supabase session.
  static String generatePreviewPublicId([Random? random]) {
    final source = random ?? Random.secure();
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final suffix = List.generate(
      6,
      (_) => alphabet[source.nextInt(alphabet.length)],
    ).join();
    return 'CL-$suffix';
  }
}
