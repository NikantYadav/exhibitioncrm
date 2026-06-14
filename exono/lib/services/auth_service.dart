import 'dart:convert';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  static const String _baseUrl = ApiConfig.baseUrl;

  /// Sign up a new user
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data['user'],
          'session': data['session'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Signup failed',
        };
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Login existing user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data['user'],
          'session': data['session'],
          'profile': data['profile'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Login failed',
        };
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Complete user profile after onboarding
  static Future<Map<String, dynamic>> completeProfile({
    required String token,
    required String name,
    required String profileType,
    String? designation,
    String? productsServices,
    String? valueProposition,
    String? website,
    String? linkedinUrl,
    required String aiTone,
    String? additionalContext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/complete-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'profile_type': profileType,
          'designation': designation,
          'products_services': productsServices,
          'value_proposition': valueProposition,
          'website': website,
          'linkedin_url': linkedinUrl,
          'ai_tone': aiTone,
          'additional_context': additionalContext,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'profile': data['profile'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Profile update failed',
        };
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get current session
  static Future<Map<String, dynamic>> getSession(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/session'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data['user'],
          'profile': data['profile'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Session invalid',
        };
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Logout user
  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Logout failed',
        };
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
