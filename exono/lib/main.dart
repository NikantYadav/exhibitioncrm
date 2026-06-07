import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_theme.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/main_screen.dart';
import 'screens/home_default_screen.dart';
import 'screens/landing_screen.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
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

          return MaterialApp(
            title: 'exhibit.ai',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/auth': (context) => const AuthScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/mode-selection': (context) => const ModeSelectionScreen(),
              '/chat': (context) => const ChatScreen(),
              '/main': (context) => const MainScreen(),
              '/home-default': (context) => const HomeDefaultScreen(),
              '/landing': (context) => const LandingScreen(),
            },
          );
        },
      ),
    );
  }
}
