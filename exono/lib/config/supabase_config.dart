class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void validate() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Missing Supabase config. Run via ./run.sh or pass:\n'
        '  --dart-define=SUPABASE_URL=...\n'
        '  --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
