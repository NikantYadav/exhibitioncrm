class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );
  
  // Endpoints
  static const String contacts = '/contacts';
  static const String events = '/events';
  static const String notes = '/notes';
  static const String captures = '/captures';
  static const String companies = '/companies';
  static const String followUps = '/follow-ups';
  static const String ai = '/ai';

  // Chat
  static const String conversations = '/conversations';
  static const String assistant = '/assistant';
}
