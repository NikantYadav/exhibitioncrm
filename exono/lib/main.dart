import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/offline/background_sync.dart';
import 'services/offline/connectivity_service.dart';
import 'services/offline/offline_queue.dart';
import 'services/offline/sync_service.dart';
import 'providers/auth_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/live_event_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/offline_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';
import 'router.dart';

/// Entry point for the workmanager background isolate. Runs detached from the
/// UI isolate, so it must initialise its own bindings and rebuild any state it
/// needs (here: just SharedPreferences-backed auth + the SQLite outbox).
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // executeTask already calls WidgetsFlutterBinding.ensureInitialized(), so
    // plugins (SharedPreferences, sqflite, path_provider) are usable here.
    try {
      // One-shot reachability probe — no stream/timer in a background task.
      final online = await ConnectivityService().checkNow();
      if (!online) return true;

      // Nothing queued -> succeed immediately so the OS doesn't back off.
      if (await OfflineQueue.retryableCount() == 0) return true;

      await SyncService().sync();
    } catch (_) {
      // Returning false asks the OS to retry with backoff.
      return false;
    }
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AnalyticsService.instance.initialize();

  SupabaseConfig.validate();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // Register background sync (mobile only).
  if (!kIsWeb) {
    await Workmanager().initialize(_callbackDispatcher);
    await BackgroundSync.registerPeriodic();
  }

  runApp(ExonoApp(themeProvider: themeProvider));
}

class ExonoApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const ExonoApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => LiveEventProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: _ExonoRouter(),
    );
  }
}

class _ExonoRouter extends StatefulWidget {
  @override
  State<_ExonoRouter> createState() => _ExonoRouterState();
}

class _ExonoRouterState extends State<_ExonoRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      context.read<AuthProvider>(),
      observers: [AnalyticsService.instance.observer],
    );
    // Start polling live event once auth is resolved
    _initLiveEventOnAuth();
    // Forward sync-time duplicate detections into the notification center.
    final notifications = context.read<NotificationProvider>();
    context.read<OfflineProvider>().onNotification = notifications.add;
  }

  void _initLiveEventOnAuth() {
    final auth = context.read<AuthProvider>();
    final sync = context.read<SyncProvider>();
    bool wasAuthenticated = auth.isAuthenticated;
    // Re-init live event provider on every auth state change (login/logout
    // cycles); start/stop the local drift cache in step with it.
    auth.addListener(() {
      if (auth.isAuthenticated) {
        final userId = auth.user!['id'] as String;
        context.read<LiveEventProvider>().init(sync.db, userId);
        sync.start(userId);
      } else if (wasAuthenticated) {
        sync.stop();
      }
      wasAuthenticated = auth.isAuthenticated;
    });
    if (auth.isAuthenticated) {
      final userId = auth.user!['id'] as String;
      context.read<LiveEventProvider>().init(sync.db, userId);
      sync.start(userId);
    }
  }

  FThemeData _buildForuiDark() {
    const c = AppTheme.darkColors;
    final colors = FColors(
      brightness: Brightness.dark,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF04060E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      barrier: Colors.black54,
      background: c.background,
      foreground: c.textPrimary,
      primary: c.accent,
      primaryForeground: Colors.white,
      secondary: c.accent,
      secondaryForeground: Colors.white,
      muted: c.surfaceAlt,
      mutedForeground: c.textMuted,
      destructive: c.destructive,
      destructiveForeground: Colors.white,
      error: c.destructive,
      errorForeground: Colors.white,
      card: c.surface,
      border: c.border,
    );
    return FThemeData(colors: colors, touch: true);
  }

  FThemeData _buildForuiLight() {
    const c = AppTheme.lightColors;
    final colors = FColors(
      brightness: Brightness.light,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF4F7FF),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      barrier: Colors.black38,
      background: c.background,
      foreground: c.textPrimary,
      primary: c.accent,
      primaryForeground: Colors.white,
      secondary: c.accent,
      secondaryForeground: Colors.white,
      muted: c.surfaceAlt,
      mutedForeground: c.textMuted,
      destructive: c.destructive,
      destructiveForeground: Colors.white,
      error: c.destructive,
      errorForeground: Colors.white,
      card: c.surface,
      border: c.border,
    );
    return FThemeData(colors: colors, touch: true);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Color(0xFF04060E),
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Color(0xFFF4F7FF),
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
    );

    final foruiTheme = isDark ? _buildForuiDark() : _buildForuiLight();

    return MaterialApp.router(
      title: 'exono',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.themeMode,
      routerConfig: _router,
      builder: (context, child) => FTheme(
        data: foruiTheme,
        child: FToaster(
          child: child!,
        ),
      ),
    );
  }
}

