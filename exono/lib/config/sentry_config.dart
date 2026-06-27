/// Sentry DSN, injected at build time via:
///   --dart-define=SENTRY_DSN=https://...ingest.sentry.io/...
/// When empty (e.g. local dev without the define), Sentry init is skipped so
/// the app runs normally without reporting.
class SentryConfig {
  static const String dsn = String.fromEnvironment('SENTRY_DSN');

  /// Build-channel label attached to every event so dev/test/prod are separable
  /// in the Sentry dashboard. Override with --dart-define=SENTRY_ENV=testflight.
  static const String environment =
      String.fromEnvironment('SENTRY_ENV', defaultValue: 'development');

  static bool get isEnabled => dsn.isNotEmpty;
}
