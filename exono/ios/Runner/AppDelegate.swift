import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register background task identifiers for offline outbox sync. These must
    // match BGTaskSchedulerPermittedIdentifiers in Info.plist and the task names
    // registered from Dart (BackgroundSyncTasks).
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "exono.background_sync",
      frequency: NSNumber(value: 15 * 60)
    )
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "exono.background_sync_oneoff"
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
