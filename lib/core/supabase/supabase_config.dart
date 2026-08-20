class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jqapiqbldvtngbilujqs.supabase.co',
  );

  // Publishable keys are intended for use in public client applications.
  // Never replace this with a Supabase secret/service-role key.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_daQzL20KKj1Tlu8w869JRg_cuuqIQiY',
  );

  static const redirectUrl = 'chocolog://login-callback/';
}
