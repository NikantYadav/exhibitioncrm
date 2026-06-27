import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Collects device + app metadata and registers it with Sentry so every
/// captured event (crash or manual feedback) carries it. Call once after
/// the app is running and (optionally) again after login to set the user.
class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  PackageInfo? _package;

  /// Human-readable one-line summary used in the manual feedback body.
  String summary = 'unknown device';

  Future<void> initialize() async {
    _package = await PackageInfo.fromPlatform();
    final version = '${_package!.version}+${_package!.buildNumber}';

    String deviceLine = 'unknown';
    final info = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final a = await info.androidInfo;
      deviceLine = 'Android ${a.version.release} (SDK ${a.version.sdkInt}) — '
          '${a.manufacturer} ${a.model}';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final i = await info.iosInfo;
      deviceLine = 'iOS ${i.systemVersion} — ${i.utsname.machine} (${i.name})';
    }

    summary = 'App $version | $deviceLine';

    // Tag every future Sentry event with app version + device for filtering.
    await Sentry.configureScope((scope) {
      scope.setTag('app_version', version);
      scope.setContexts('device_summary', {'value': deviceLine});
    });
  }

  /// Associate reports with the logged-in user (id only — no PII beyond id).
  Future<void> setUser(String? userId) async {
    await Sentry.configureScope((scope) {
      scope.setUser(userId == null ? null : SentryUser(id: userId));
    });
  }
}
