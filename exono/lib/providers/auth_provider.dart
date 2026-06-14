import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _profile;
  String? _accessToken;
  bool _isLoading = false;
  bool _initialized = false;

  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _accessToken != null && _user != null;
  bool get onboardingCompleted => (_profile?['onboarding_completed'] as bool?) == true;
  bool get initialized => _initialized;

  /// Display name derived from profile or user metadata
  String get displayName {
    if (_profile != null) {
      final name = _profile!['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    }
    if (_user != null) {
      final meta = _user!['user_metadata'] as Map<String, dynamic>?;
      final name = meta?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
      final email = _user!['email'] as String?;
      if (email != null) return email.split('@').first;
    }
    return 'User';
  }

  /// Initials for avatar
  String get initials {
    final name = displayName;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String get designation {
    if (_profile != null) {
      final d = _profile!['designation'] as String?;
      if (d != null && d.isNotEmpty) return d.toUpperCase();
      final role = _profile!['employee_role'] as String?;
      if (role != null && role.isNotEmpty) return role.toUpperCase();
    }
    return 'TEAM MEMBER';
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // Ensure any 401 response from the API triggers an immediate logout.
    ApiService.onUnauthorized = () async {
      final prefs = await SharedPreferences.getInstance();
      await _clearSession(prefs);
      notifyListeners();
    };

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null && token.isNotEmpty) {
        final result = await AuthService.getSession(token);
        if (result['success'] == true) {
          _accessToken = token;
          _user = result['user'] as Map<String, dynamic>?;
          _profile = result['profile'] as Map<String, dynamic>?;
          // Keep Supabase realtime auth in sync
          _syncRealtimeAuth(token);
        } else {
          await _clearSession(prefs);
        }
      }
    } catch (_) {
      // ignore — will stay unauthenticated
    } finally {
      _initialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await AuthService.login(email: email, password: password);
      if (result['success'] == true) {
        final session = result['session'] as Map<String, dynamic>?;
        final token = session?['access_token'] as String?;
        final refresh = session?['refresh_token'] as String?;
        if (token != null) {
          _accessToken = token;
          _user = result['user'] as Map<String, dynamic>?;
          _profile = result['profile'] as Map<String, dynamic>?;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);
          if (refresh != null) await prefs.setString('refresh_token', refresh);
          _syncRealtimeAuth(token);
        }
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await AuthService.signup(
          email: email, password: password, name: name);
      if (result['success'] == true) {
        final session = result['session'] as Map<String, dynamic>?;
        final token = session?['access_token'] as String?;
        final refresh = session?['refresh_token'] as String?;
        if (token != null) {
          _accessToken = token;
          _user = result['user'] as Map<String, dynamic>?;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);
          if (refresh != null) await prefs.setString('refresh_token', refresh);
          _syncRealtimeAuth(token);
        }
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_accessToken == null) return;
    try {
      final result = await AuthService.getSession(_accessToken!);
      if (result['success'] == true) {
        _profile = result['profile'] as Map<String, dynamic>?;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? designation,
    String? website,
    String? linkedinUrl,
    String? productsServices,
    String? valueProposition,
    String? additionalContext,
    String? aiTone,
  }) async {
    if (_accessToken == null) return {'success': false, 'error': 'Not authenticated'};
    try {
      final result = await AuthService.completeProfile(
        token: _accessToken!,
        name: name,
        profileType: (_profile?['profile_type'] as String?) ?? 'individual',
        designation: designation,
        productsServices: productsServices,
        valueProposition: valueProposition,
        website: website,
        linkedinUrl: linkedinUrl,
        aiTone: aiTone ?? ((_profile?['ai_tone'] as String?) ?? 'professional'),
        additionalContext: additionalContext,
      );
      if (result['success'] == true) {
        _profile = result['profile'] as Map<String, dynamic>?;
        notifyListeners();
      }
      return result;
    } catch (_) {
      return {'success': false, 'error': 'Unable to connect. Please check your internet connection and try again.'};
    }
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    _accessToken = null;
    _user = null;
    _profile = null;
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('selected_mode');
  }

  void _syncRealtimeAuth(String token) {
    try {
      // Supabase.instance.client.realtime.setAuth(token);
      // Called lazily when Supabase is initialized
    } catch (_) {}
  }
}
