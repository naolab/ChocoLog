import 'package:chocolog/core/supabase/supabase_config.dart';
import 'package:chocolog/core/supabase/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseAuthRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final supabaseSessionProvider = StreamProvider<Session?>((ref) {
  final client = SupabaseService.client;
  if (client == null) return Stream.value(null);
  return client.auth.onAuthStateChange.map((state) => state.session);
});

class SupabaseAuthRepository {
  SupabaseClient get _client =>
      SupabaseService.client ??
      (throw StateError('Supabase has not been initialized'));

  User? get currentUser => _client.auth.currentUser;

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.redirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
