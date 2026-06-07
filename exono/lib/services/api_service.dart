import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/contact.dart';
import '../models/event.dart';

class ApiService {
  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<List<Contact>> getContacts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((json) => Contact.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load contacts');
    }
  }

  static Future<Contact> createContact(Map<String, dynamic> contactData) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}'),
      headers: await _headers(),
      body: json.encode(contactData),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Contact.fromJson(data['data']);
    } else {
      throw Exception('Failed to create contact');
    }
  }

  static Future<List<Event>> getEvents() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((json) => Event.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load events');
    }
  }

  static Future<List<Map<String, dynamic>>> getContactTimeline(String contactId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/timeline'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load contact timeline');
    }
  }

  static Future<Map<String, dynamic>> enrichContact(String contactId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/contacts/$contactId/enrich'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to enrich contact');
    }
  }

  static Future<Event> createEvent(Map<String, dynamic> eventData) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}'),
      headers: await _headers(),
      body: json.encode(eventData),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    } else {
      throw Exception('Failed to create event');
    }
  }

  static Future<Map<String, dynamic>> analyzeCard(String imageData) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ai}/analyze-card'),
      headers: await _headers(),
      body: json.encode({'image': imageData}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to analyze card');
    }
  }

  static Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/dashboard/summary'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load dashboard summary');
    }
  }

  // Chat: create or reuse a global conversation
  static Future<Map<String, dynamic>> getOrCreateGlobalConversation() async {
    return createConversation(kind: 'global');
  }

  static Future<Map<String, dynamic>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    var url =
        '${ApiConfig.baseUrl}${ApiConfig.conversations}/$conversationId/messages?limit=$limit';
    if (before != null) url += '&before=${Uri.encodeComponent(before)}';

    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'data': (data['data'] as List).cast<Map<String, dynamic>>(),
        'next_before': data['next_before'],
      };
    }
    throw Exception('Failed to load messages');
  }

  static Future<List<Map<String, dynamic>>> searchMessages(
      String conversationId, String query,
      {int limit = 20}) async {
    final url =
        '${ApiConfig.baseUrl}${ApiConfig.conversations}/$conversationId/messages/search?q=${Uri.encodeComponent(query)}&limit=$limit';
    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to search messages');
  }

  static Future<List<Map<String, dynamic>>> listConversations({
    String? kind,
    String? contactId,
    String? eventId,
  }) async {
    var url = '${ApiConfig.baseUrl}${ApiConfig.conversations}';
    final params = <String>[];
    if (kind != null) params.add('kind=${Uri.encodeComponent(kind)}');
    if (contactId != null) params.add('contact_id=${Uri.encodeComponent(contactId)}');
    if (eventId != null) params.add('event_id=${Uri.encodeComponent(eventId)}');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to list conversations');
  }

  static Future<Map<String, dynamic>> createConversation({
    required String kind,
    String? title,
    String? contactId,
    String? eventId,
  }) async {
    final body = <String, dynamic>{'kind': kind};
    if (title != null) body['title'] = title;
    if (contactId != null) body['contact_id'] = contactId;
    if (eventId != null) body['event_id'] = eventId;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}'),
      headers: await _headers(),
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create conversation');
  }

  static Future<Map<String, dynamic>> assistantRespond({
    required String conversationId,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assistant}/respond'),
      headers: await _headers(),
      body: json.encode({'conversation_id': conversationId, 'text': text}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final body = json.decode(response.body);
    throw Exception(body is Map && body['error'] != null ? body['error'] : 'Assistant error');
  }

  static Future<void> deleteConversation(String conversationId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}/$conversationId'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete conversation');
    }
  }

  static Future<Map<String, dynamic>> generateEmailDraft({
    required String contactId,
    String? eventId,
    required String emailType,
    String? customContext,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/emails/draft'),
      headers: await _headers(),
      body: json.encode({
        'contact_id': contactId,
        'event_id': eventId,
        'email_type': emailType,
        'custom_context': customContext,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to generate email draft');
  }

  static Future<Map<String, dynamic>> logInteraction({
    required String contactId,
    String? eventId,
    required String type,
    required String summary,
    Map<String, dynamic>? details,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/interactions'),
      headers: await _headers(),
      body: json.encode({
        'contact_id': contactId,
        'event_id': eventId,
        'interaction_type': type,
        'summary': summary,
        'details': details,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log interaction');
  }
}
