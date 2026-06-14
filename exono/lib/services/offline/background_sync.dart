import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:workmanager/workmanager.dart';

/// Workmanager task identifiers. Kept here so both [main] (which registers the
/// periodic task + the callback dispatcher) and [BackgroundSync] (which enqueues
/// one-off retries) share the same names.
class BackgroundSyncTasks {
  static const periodic = 'exono.background_sync';
  static const oneOff = 'exono.background_sync_oneoff';
}

/// Thin wrapper over workmanager for scheduling outbox replay while the app is
/// backgrounded or killed. The actual work runs in the callback dispatcher in
/// main.dart.
class BackgroundSync {
  /// Registers the recurring sync task. Android enforces a 15-minute minimum.
  static Future<void> registerPeriodic() async {
    if (kIsWeb) return;
    await Workmanager().registerPeriodicTask(
      BackgroundSyncTasks.periodic,
      BackgroundSyncTasks.periodic,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Enqueues a one-off sync, gated on connectivity. Call this when ops are
  /// queued while offline so a replay is attempted as soon as the device
  /// regains a connection — even if the app is no longer in the foreground.
  static Future<void> scheduleOneOff() async {
    if (kIsWeb) return;
    await Workmanager().registerOneOffTask(
      // Unique-per-schedule name keeps it from coalescing with the periodic
      // task while still replacing a prior pending one-off.
      BackgroundSyncTasks.oneOff,
      BackgroundSyncTasks.oneOff,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      initialDelay: const Duration(seconds: 10),
    );
  }
}
