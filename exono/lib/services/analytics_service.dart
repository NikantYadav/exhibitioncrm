import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

/// Thin wrapper around Firebase Analytics and UXCam.
/// Call [AnalyticsService.instance] after [initialize] has completed.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  late final FirebaseAnalytics _fa;
  late final FirebaseAnalyticsObserver observer;

  // UXCam app key. Supplied per-build with --dart-define=UXCAM_APP_KEY=...
  // (empty when unset -> UXCam init is skipped).
  static const String _uxcamKey = String.fromEnvironment('UXCAM_APP_KEY');

  Future<void> initialize() async {
    _fa = FirebaseAnalytics.instance;
    observer = FirebaseAnalyticsObserver(analytics: _fa);

    if (!kIsWeb && _uxcamKey.isNotEmpty) {
      // Capture gesture/screen recordings. Only enable once you have user
      // consent for screen recording.
      FlutterUxcam.optIntoSchematicRecordings();
      final config = FlutterUxConfig(
        userAppKey: _uxcamKey,
        // We tag screens manually via [logScreen] / the router observer.
        enableAutomaticScreenNameTagging: false,
        enableIntegrationLogging: !kReleaseMode,
      );
      await FlutterUxcam.startWithConfiguration(config);
    }
  }

  // ── Screen tracking ───────────────────────────────────────────────────────

  Future<void> logScreen(String screenName) async {
    await _fa.logScreenView(screenName: screenName);
    if (!kIsWeb) {
      await FlutterUxcam.tagScreenName(screenName);
    }
  }

  // ── Auth events ───────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) async {
    await _fa.logLogin(loginMethod: method);
    if (!kIsWeb) await FlutterUxcam.logEvent('login');
  }

  Future<void> logSignUp({String method = 'email'}) async {
    await _fa.logSignUp(signUpMethod: method);
    if (!kIsWeb) await FlutterUxcam.logEvent('sign_up');
  }

  Future<void> setUserId(String? userId) async {
    await _fa.setUserId(id: userId);
    if (!kIsWeb && userId != null) {
      await FlutterUxcam.setUserIdentity(userId);
    }
  }

  Future<void> setUserProperty(String name, String value) async {
    await _fa.setUserProperty(name: name, value: value);
    if (!kIsWeb) {
      await FlutterUxcam.setUserProperty(name, value);
    }
  }

  // ── CRM-specific events ───────────────────────────────────────────────────

  Future<void> logContactAdded({required String method}) =>
      _logEvent('contact_added', {'method': method});

  Future<void> logContactViewed() => _logEvent('contact_viewed');

  Future<void> logCaptureStarted({required String mode}) =>
      _logEvent('capture_started', {'mode': mode});

  Future<void> logCaptureCompleted({required String mode}) =>
      _logEvent('capture_completed', {'mode': mode});

  Future<void> logEventCreated() => _logEvent('event_created');

  Future<void> logFollowUpCompleted() => _logEvent('follow_up_completed');

  Future<void> logChatMessageSent() => _logEvent('chat_message_sent');

  Future<void> logAIAssistantUsed({required String context}) =>
      _logEvent('ai_assistant_used', {'context': context});

  Future<void> logSearch({required String tab}) =>
      _logEvent('search_performed', {'tab': tab});

  Future<void> logImportContacts({required String source}) =>
      _logEvent('import_contacts', {'source': source});

  // ── Internal helper ───────────────────────────────────────────────────────

  Future<void> _logEvent(String name, [Map<String, Object>? params]) async {
    await _fa.logEvent(name: name, parameters: params);
    if (!kIsWeb) {
      if (params != null && params.isNotEmpty) {
        await FlutterUxcam.logEventWithProperties(name, params);
      } else {
        await FlutterUxcam.logEvent(name);
      }
    }
  }
}
