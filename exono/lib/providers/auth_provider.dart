import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/exo_chat_sheet.dart';

/// Secure storage instance used for all sensitive keys (tokens + identity cache).
/// Android: EncryptedSharedPreferences backed by the Android Keystore.
/// iOS/macOS: Keychain.
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Keys stored in FlutterSecureStorage (sensitive).
const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kCachedUser = 'cached_user';
const _kCachedProfile = 'cached_profile';
const _kLastVerifiedMs = 'session_last_verified_ms';

/// Perform a one-time migration of sensitive values from SharedPreferences
/// (where they lived before this version) to secure storage, then wipe them
/// from prefs so they no longer sit in plaintext. Safe to call on every start;
/// it is a no-op once the values are gone from prefs.
Future<void> _migrateFromPrefsIfNeeded(SharedPreferences prefs) async {
  final keysToMigrate = [
    _kAccessToken,
    _kRefreshToken,
    _kCachedUser,
    _kCachedProfile,
  ];
  for (final key in keysToMigrate) {
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) {
      // Only write to secure storage if the key is not already there (don't
      // overwrite a newer value that was already written by this version).
      final alreadySecure = await _secureStorage.read(key: key);
      if (alreadySecure == null || alreadySecure.isEmpty) {
        await _secureStorage.write(key: key, value: existing);
      }
      await prefs.remove(key);
    }
  }
  // session_last_verified_ms is an int in prefs; migrate it too.
  final lastMs = prefs.getInt(_kLastVerifiedMs);
  if (lastMs != null) {
    final alreadySecure = await _secureStorage.read(key: _kLastVerifiedMs);
    if (alreadySecure == null || alreadySecure.isEmpty) {
      await _secureStorage.write(key: _kLastVerifiedMs, value: lastMs.toString());
    }
    await prefs.remove(_kLastVerifiedMs);
  }
}

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
    }
    return 'TEAM MEMBER';
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // A 401 only reaches here after ApiService has already tried (and failed)
    // to refresh the token, so the session is genuinely unrecoverable: log out.
    ApiService.onUnauthorized = () async {
      await _clearSession();
      notifyListeners();
    };

    // When ApiService silently refreshes the access token, keep our in-memory
    // copy and Supabase realtime auth in sync so the user stays logged in.
    ApiService.onTokenRefreshed = (newToken) {
      _accessToken = newToken;
      _syncRealtimeAuth(newToken);
    };

    _isLoading = true;
    notifyListeners();

    try {
      // Migrate any values still sitting in plaintext SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      await _migrateFromPrefsIfNeeded(prefs);

      var token = await _secureStorage.read(key: _kAccessToken);
      if (token != null && token.isNotEmpty) {
        var result = await AuthService.getSession(token);
        // The stored access token may have expired while the app was closed.
        // Try to recover the session with the refresh token before giving up.
        // Skip the refresh attempt if the session check failed purely because
        // we're offline — the refresh would fail the same way.
        if (result['success'] != true && result['network'] != true) {
          final refresh = await _secureStorage.read(key: _kRefreshToken);
          if (refresh != null && refresh.isNotEmpty) {
            final refreshed = await AuthService.refresh(refresh);
            final session = refreshed['session'] as Map<String, dynamic>?;
            final newToken = session?['access_token'] as String?;
            if (refreshed['success'] == true && newToken != null && newToken.isNotEmpty) {
              token = newToken;
              await _secureStorage.write(key: _kAccessToken, value: newToken);
              final newRefresh = session?['refresh_token'] as String?;
              if (newRefresh != null && newRefresh.isNotEmpty) {
                await _secureStorage.write(key: _kRefreshToken, value: newRefresh);
              }
              result = await AuthService.getSession(newToken);
            } else if (refreshed['network'] == true) {
              // Refresh also couldn't reach the server — treat as offline.
              result = {'success': false, 'network': true};
            }
          }
        }
        if (result['success'] == true) {
          _accessToken = token;
          _user = result['user'] as Map<String, dynamic>?;
          _profile = result['profile'] as Map<String, dynamic>?;
          await _cacheIdentity();
          // Keep Supabase realtime auth in sync
          _syncRealtimeAuth(token);
        } else if (result['network'] == true &&
            await _offlineRestoreAllowed() &&
            await _restoreCachedIdentity()) {
          // Offline: the token couldn't be verified, but it isn't rejected
          // either. Keep the user signed in from cache so they can work offline;
          // the token is revalidated (and refreshed if needed) once back online.
          // Only reached when the session is within the offline grace window
          // (see _offlineRestoreAllowed).
          _accessToken = token;
          _syncRealtimeAuth(token);
        } else {
          // Genuine auth rejection, expired token, stale offline session, or no
          // cached identity — sign out.
          await _clearSession();
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
          await _secureStorage.write(key: _kAccessToken, value: token);
          if (refresh != null) {
            await _secureStorage.write(key: _kRefreshToken, value: refresh);
          }
          await _cacheIdentity();
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
          await _secureStorage.write(key: _kAccessToken, value: token);
          if (refresh != null) {
            await _secureStorage.write(key: _kRefreshToken, value: refresh);
          }
          await _cacheIdentity();
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
    await _clearSession();
    clearExoSessions();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_accessToken == null) return;
    try {
      final result = await AuthService.getSession(_accessToken!);
      if (result['success'] == true) {
        _profile = result['profile'] as Map<String, dynamic>?;
        await _cacheIdentity();
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
        await _cacheIdentity();
        notifyListeners();
      }
      return result;
    } catch (_) {
      return {'success': false, 'error': 'Unable to connect. Please check your internet connection and try again.'};
    }
  }

  /// Maximum time an offline session may be honoured without a successful
  /// server-side token verification. Even though the backend re-verifies every
  /// online request, this bounds how long a stolen device can keep reading
  /// cached data with airplane mode on. The token's own `exp` is also enforced
  /// (see [initialize]); whichever is sooner wins.
  static const _offlineGraceDuration = Duration(days: 7);

  /// Caches the current user/profile JSON so the app can restore an
  /// authenticated session offline (when the server can't be reached to verify
  /// the token). Called whenever a fresh session/profile is obtained.
  Future<void> _cacheIdentity() async {
    if (_user != null) {
      await _secureStorage.write(key: _kCachedUser, value: jsonEncode(_user));
    }
    if (_profile != null) {
      await _secureStorage.write(key: _kCachedProfile, value: jsonEncode(_profile));
    }
    // Stamp the moment of a confirmed server-side verification. Used to bound
    // how long the session may be restored purely from cache while offline.
    await _secureStorage.write(
      key: _kLastVerifiedMs,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Decides whether a cached session may be honoured offline. Enforced locally
  /// so a stolen/airplane-mode device cannot hold access indefinitely. The
  /// server still re-verifies the token on the next online request and a real
  /// rejection then forces logout.
  ///
  /// Note we do NOT hard-gate on the *access* token's `exp`: access tokens are
  /// short-lived (~1h) and refreshing them needs network, so a legitimately
  /// offline user's access token is normally already expired. The session's true
  /// lifetime is bounded instead by the time since the last *confirmed* server
  /// verification — a missing/garbled timestamp is treated as expired
  /// (fail closed).
  Future<bool> _offlineRestoreAllowed() async {
    final lastStr = await _secureStorage.read(key: _kLastVerifiedMs);
    if (lastStr == null) return false;
    final lastMs = int.tryParse(lastStr);
    if (lastMs == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final elapsed = DateTime.now().difference(last);
    // Reject negative elapsed too (clock rolled back to dodge the cap).
    if (elapsed.isNegative || elapsed > _offlineGraceDuration) return false;
    return true;
  }

  /// Restores user/profile from the offline cache. Returns true if a cached
  /// identity was found and loaded.
  Future<bool> _restoreCachedIdentity() async {
    final userJson = await _secureStorage.read(key: _kCachedUser);
    if (userJson == null) return false;
    try {
      _user = jsonDecode(userJson) as Map<String, dynamic>;
      final profileJson = await _secureStorage.read(key: _kCachedProfile);
      if (profileJson != null) {
        _profile = jsonDecode(profileJson) as Map<String, dynamic>;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _user = null;
    _profile = null;
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
    await _secureStorage.delete(key: _kCachedUser);
    await _secureStorage.delete(key: _kCachedProfile);
    await _secureStorage.delete(key: _kLastVerifiedMs);
    // Also clear non-sensitive prefs.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_mode');
  }

  void _syncRealtimeAuth(String token) {
    try {
      Supabase.instance.client.realtime.setAuth(token);
    } catch (_) {}
  }
}
