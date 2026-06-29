import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Soft device integrity check. Returns true if the device appears to be
/// rooted (Android) or jailbroken (iOS). Never throws — returns false on any
/// error so a detection failure never blocks the user.
class DeviceIntegrityService {
  /// Returns true if the device appears compromised (rooted / jailbroken).
  /// Always returns false on web or on any plugin error.
  static Future<bool> isCompromised() async {
    if (kIsWeb) return false;
    try {
      final jailbroken = await FlutterJailbreakDetection.jailbroken;
      if (jailbroken) return true;
      // developerMode is Android-only; ignore on iOS (returns false there).
      final devMode = await FlutterJailbreakDetection.developerMode;
      return devMode;
    } catch (_) {
      return false;
    }
  }
}
