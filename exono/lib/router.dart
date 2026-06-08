import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/events_screen.dart';
import 'screens/follow_ups_screen.dart';
import 'screens/home_default_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/meetings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final loc = state.matchedLocation;
      final onPublic = loc == '/auth' || loc == '/landing' || loc == '/onboarding';

      if (!loggedIn && !onPublic) return kIsWeb ? '/landing' : '/auth';
      if (loggedIn && onPublic)  return '/';
      return null;
    },
    routes: [
      // ── Public / auth routes (no shell) ──────────────────────────────────
      GoRoute(path: '/landing',    builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/auth',       builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      // ── Capture — full-screen modal, no nav shell ─────────────────────────
      GoRoute(path: '/capture', builder: (_, __) => const CaptureScreen()),

      // ── Chat ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/chat',
        builder: (_, state) {
          final msg = state.uri.queryParameters['msg'];
          return ChatScreen(initialMessage: msg, isNewChat: msg != null);
        },
      ),

      // ── App shell — all tab routes render inside AppShell ─────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeDefaultScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (_, __) => const EventsScreen(),
          ),
          GoRoute(
            path: '/contacts',
            builder: (_, __) => const ContactsScreen(),
          ),
          GoRoute(
            path: '/follow-ups',
            builder: (_, __) => const FollowUpsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/meetings',
            builder: (_, __) => const MeetingsScreen(),
          ),
        ],
      ),
    ],
  );
}
