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
import 'services/offline/connectivity_service.dart';
import 'services/offline/sync_service.dart';
import 'providers/auth_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/live_event_provider.dart';
import 'providers/offline_provider.dart';
import 'providers/theme_provider.dart';
import 'router.dart';

/// Background task name for periodic sync.
const _kSyncTaskName = 'exono.background_sync';

/// Called by workmanager in a background isolate.
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await ConnectivityService().initialize();
      if (ConnectivityService().isOnline) {
        await SyncService().sync();
      }
    } catch (_) {}
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseConfig.validate();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // Register background sync (mobile only).
  if (!kIsWeb) {
    await Workmanager().initialize(_callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _kSyncTaskName,
      _kSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
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
    _router = buildRouter(context.read<AuthProvider>());
    // Start polling live event once auth is resolved
    _initLiveEventOnAuth();
  }

  void _initLiveEventOnAuth() {
    final auth = context.read<AuthProvider>();
    // Re-init live event provider on every auth state change (login/logout cycles)
    auth.addListener(() {
      if (auth.isAuthenticated) {
        context.read<LiveEventProvider>().init();
      }
    });
    if (auth.isAuthenticated) {
      context.read<LiveEventProvider>().init();
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

