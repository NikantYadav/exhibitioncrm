import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/live_event_provider.dart';
import 'providers/theme_provider.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseConfig.validate();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final themeProvider = ThemeProvider();
  await themeProvider.load();

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

    return MaterialApp.router(
      title: 'exono',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.themeMode,
      routerConfig: _router,
    );
  }
}

