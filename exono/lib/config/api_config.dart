class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://localhost:3001/api',
    defaultValue: 'https://exhibitioncrm.vercel.app/api',
  );

  /// Fails fast at startup if the configured base URL is not HTTPS, so a
  /// misconfigured build cannot silently send CRM data over cleartext.
  static void assertSecure() {
    final uri = Uri.tryParse(baseUrl);
    assert(
      uri != null && uri.scheme == 'https',
      'API_BASE_URL must be an absolute https:// URL, got: $baseUrl',
    );
  }
  
  // Endpoints
  static const String contacts = '/contacts';
  static const String events = '/events';
  static const String captures = '/captures';
  static const String companies = '/companies';
  static const String followUps = '/follow-ups';
  static const String ai = '/ai';
  static const String sync = '/sync';

  // Chat
  static const String conversations = '/conversations';
  static const String assistant = '/assistant';
}
