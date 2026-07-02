import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'models/event.dart';
import 'providers/auth_provider.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/chat_history_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/company_detail_screen.dart';
import 'screens/contact_detail_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/event_router_screen.dart';
import 'screens/events_screen.dart';
import 'screens/follow_ups_screen.dart';
import 'screens/home_default_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/splash_screen_motion.dart';
import 'screens/live_home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/account_settings_screen.dart';
import 'screens/voice_contact_capture_screen.dart';

/// Root navigator key. Full-screen routes (company/contact/event detail,
/// capture, live event, chat) declare `parentNavigatorKey: rootNavigatorKey`
/// so they render on the root navigator — structurally ABOVE/OUTSIDE the
/// AppShell — and never inherit the bottom nav bar or live bar.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigator key for the app shell's nested navigator. Full-screen detail
/// screens push onto [rootNavigatorKey] instead, so they render above the
/// shell with no bottom nav / live bar; this key is kept for the defensive
/// pop-to-root on tab switch in AppShell.
final shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AuthProvider auth, {List<NavigatorObserver>? observers}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: kIsWeb ? '/' : '/splash',
    refreshListenable: auth,
    observers: observers ?? [],
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final onboarded = auth.onboardingCompleted;
      final loc = state.matchedLocation;
      final onPublic = loc == '/auth' || loc == '/landing' || loc == '/onboarding' || loc == '/splash';

      if (loc == '/splash') return null;
      if (!loggedIn && !onPublic) return kIsWeb ? '/landing' : '/auth';
      if (loggedIn && !onboarded && loc != '/onboarding') return '/onboarding';
      if (loggedIn && onboarded && onPublic) return '/';
      return null;
    },
    routes: [
      // ── Public / auth routes (no shell) ──────────────────────────────────
      GoRoute(path: '/splash',     builder: (_, _) => const MotionSplashScreen()),
      GoRoute(path: '/landing',    builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/auth',       builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),

      // ── Capture — full-screen modal, no nav shell ─────────────────────────
      GoRoute(path: '/capture', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const CaptureScreen()),
      GoRoute(path: '/voice-capture', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const VoiceContactCaptureScreen()),

      // ── Live event floor — full-screen (no nav shell) ──────────────────────
      GoRoute(path: '/live-event', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const LiveHomeScreen()),

      // ── Company detail — full-screen (no nav shell needed) ────────────────
      GoRoute(
        path: '/companies/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final companyId = state.pathParameters['id']!;
          return CompanyDetailScreen(companyId: companyId);
        },
      ),

      // ── Event detail — routes to prep/follow-up/live based on status ────────
      GoRoute(
        path: '/events/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final eventId = state.pathParameters['id']!;
          final event = state.extra is Event ? state.extra as Event : null;
          return EventRouterScreen(eventId: eventId, event: event);
        },
      ),

      // ── Contact detail — full-screen (no nav shell needed) ────────────────
      GoRoute(
        path: '/contacts/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final contactId = state.pathParameters['id']!;
          return ContactDetailScreen(contactId: contactId);
        },
      ),

      // ── App shell — all tab routes render inside AppShell ─────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HomeDefaultScreen(),
          ),
          GoRoute(
            path: '/events',
            builder: (_, _) => const EventsScreen(),
          ),
          GoRoute(
            path: '/contacts',
            builder: (_, _) => const ContactsScreen(),
          ),
          GoRoute(
            path: '/follow-ups',
            builder: (_, _) => const FollowUpsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const AccountSettingsScreen(),
          ),
          GoRoute(
            path: '/chat-history',
            builder: (_, _) => const ChatHistoryScreen(),
          ),
        ],
      ),

      // ── Chat — full-screen (no nav shell / live bar) ─────────────────────
      GoRoute(
        path: '/chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) {
          final msg = state.uri.queryParameters['msg'];
          return ChatScreen(initialMessage: msg, isNewChat: msg != null);
        },
      ),
    ],
  );
}
