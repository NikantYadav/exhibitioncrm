import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/contact.dart';
import '../models/event.dart';

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class ApiService {
  /// Called when any request receives a 401. Set by AuthProvider on init.
  static void Function()? onUnauthorized;

  static void checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw const UnauthorizedException();
    }
  }

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

  static Future<Map<String, String>> _headersWithKey(String? idempotencyKey) async {
    final h = await _headers();
    if (idempotencyKey != null) h['Idempotency-Key'] = idempotencyKey;
    return h;
  }

  static Future<List<Contact>> getContacts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}'),
      headers: await _headers(),
    );

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((json) => Contact.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load contacts');
    }
  }

  static Future<Map<String, dynamic>> getContact(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$id'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load contact');
  }

  static Future<Contact> createContact(
    Map<String, dynamic> contactData, {
    String? idempotencyKey,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}'),
      headers: await _headersWithKey(idempotencyKey),
      body: json.encode(contactData),
    );

    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return Contact.fromJson(data['data']);
    } else if (response.statusCode == 409) {
      // Idempotent replay — return existing contact.
      final data = json.decode(response.body);
      return Contact.fromJson(data['data']);
    } else {
      throw Exception(
        'Failed to create contact (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<List<Event>> getEvents() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}'),
      headers: await _headers(),
    );

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((json) => Event.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load events');
    }
  }

  static Future<Event> getEvent(String eventId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    } else {
      throw Exception('Failed to load event');
    }
  }

  static Future<List<Map<String, dynamic>>> getContactTimeline(String contactId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/timeline'),
      headers: await _headers(),
    );

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load contact timeline');
    }
  }

  static Future<Event> createEvent(
    Map<String, dynamic> eventData, {
    String? idempotencyKey,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}'),
      headers: await _headersWithKey(idempotencyKey),
      body: json.encode(eventData),
    );

    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    } else {
      throw Exception(
        'Failed to create event (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<Map<String, dynamic>> analyzeCard(String imageData) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ai}/analyze-card'),
      headers: await _headers(),
      body: json.encode({'image': imageData}),
    );

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'Failed to analyze card (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<Map<String, dynamic>> getAllFollowUps() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/follow-ups'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load follow-ups');
  }

  static Future<Map<String, dynamic>> getDashboardPriorities() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/dashboard/priorities'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load dashboard priorities');
    }
  }

  // Chat: create or reuse a global conversation
  static Future<Map<String, dynamic>> getOrCreateGlobalConversation() async {
    return createConversation();
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

    checkUnauthorized(response);
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
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to search messages');
  }

  static Future<List<Map<String, dynamic>>> listConversations() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to list conversations');
  }

  static Future<Map<String, dynamic>> createConversation({
    String? title,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}'),
      headers: await _headers(),
      body: json.encode(body),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create conversation');
  }

  static Future<Map<String, dynamic>> assistantRespond({
    required String conversationId,
    required String text,
    bool researchMode = false,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assistant}/respond'),
      headers: await _headers(),
      body: json.encode({
        'conversation_id': conversationId,
        'text': text,
        if (researchMode) 'research_mode': true,
      }),
    );

    checkUnauthorized(response);
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

    checkUnauthorized(response);
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

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to generate email draft');
  }

  static Future<void> updateContact(String contactId, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId'),
      headers: await _headers(),
      body: json.encode(data),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update contact');
    }
  }

  static Future<List<Map<String, dynamic>>> getContactEvents(String contactId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/events'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    throw Exception('Failed to load contact events');
  }

  static Future<void> linkContactToEvent(String contactId, String eventId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/events'),
      headers: await _headers(),
      body: json.encode({'event_id': eventId}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to link event');
  }

  static Future<void> unlinkContactFromEvent(String contactId, String eventId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/events/$eventId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to unlink event');
  }

  static Future<Map<String, dynamic>> getEventStats(String eventId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/stats'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load event stats');
  }

  static Future<Map<String, Map<String, dynamic>>> getEventStatsBatch(List<String> eventIds) async {
    if (eventIds.isEmpty) return {};
    final ids = eventIds.join(',');
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/stats/batch?ids=$ids'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final raw = json.decode(response.body)['data'] as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
    }
    throw Exception('Failed to load batch event stats');
  }

  static Future<Map<String, dynamic>> getEventTarget(String eventId, String targetId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load event target');
  }

  static Future<List<Map<String, dynamic>>> getEventTargets(String eventId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load event targets');
  }

  static Future<void> markFollowUpSent(
    String eventId,
    String contactId, {
    String? subject,
    String? body,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId'),
      headers: await _headers(),
      body: json.encode({
        'action': 'send',
        'subject': ?subject,
        'body': ?body,
      }),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to mark follow-up as sent');
    }
  }

  static Future<void> unskipFollowUp(String eventId, String contactId) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId'),
      headers: await _headers(),
      body: json.encode({'action': 'unskip'}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to unskip follow-up');
    }
  }

  static Future<void> skipFollowUp(String eventId, String contactId) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId'),
      headers: await _headers(),
      body: json.encode({'action': 'skip'}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to skip follow-up');
    }
  }

  static Future<Map<String, String>> generateFollowUpDraft(
      String eventId, String contactId) async {
    final response = await http.post(
      Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId/draft'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'subject': data['subject'] as String? ?? '',
        'body': data['body'] as String? ?? '',
      };
    }
    throw Exception('Failed to generate draft');
  }

  static Future<void> deleteEvent(String eventId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete event');
    }
  }

  static Future<Event> updateEvent(String eventId, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId'),
      headers: await _headers(),
      body: json.encode(data),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return Event.fromJson(body['data']);
    }
    throw Exception('Failed to update event');
  }

  static Future<void> deleteContact(String contactId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete contact');
    }
  }

  static Future<Map<String, dynamic>> getContactInsights(String contactId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/insights'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load contact insights');
  }

  static Future<Map<String, dynamic>> logInteraction({
    required String contactId,
    String? eventId,
    required String type,
    required String summary,
    String? interactionDate,
    Map<String, dynamic>? details,
    String? idempotencyKey,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/interactions'),
      headers: await _headersWithKey(idempotencyKey),
      body: json.encode({
        'contact_id': contactId,
        'event_id': ?eventId,
        'interaction_type': type,
        'summary': summary,
        'interaction_date': ?interactionDate,
        'details': ?details,
      }),
    );

    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to log interaction (${response.statusCode}): ${response.body}',
    );
  }

  static Future<void> updateInteraction(String id, Map<String, dynamic> updates) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/interactions/$id'),
      headers: await _headers(),
      body: json.encode(updates),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update interaction');
    }
  }

  static Future<List<Map<String, dynamic>>> getCompanies({String? query}) async {
    final url = query != null && query.isNotEmpty
        ? '${ApiConfig.baseUrl}${ApiConfig.companies}?q=${Uri.encodeComponent(query)}'
        : '${ApiConfig.baseUrl}${ApiConfig.companies}';
    final response = await http.get(Uri.parse(url), headers: await _headers());
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load companies');
  }

  static Future<Map<String, dynamic>> getCompany(String companyId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}/$companyId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load company');
  }

  static Future<Map<String, dynamic>> enrichCompany(String id, {bool force = false}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}/$id/enrich'),
      headers: await _headers(),
      body: json.encode({'force': force}),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    throw Exception(json.decode(response.body)['error'] ?? 'Failed to enrich company');
  }

  static Future<List<String>> generateCompanyBriefing(String id, {String? notes}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}/$id/briefing'),
      headers: await _headers(),
      body: notes != null && notes.trim().isNotEmpty ? json.encode({'notes': notes.trim()}) : null,
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      return (data['talking_points'] as List).cast<String>();
    }
    throw Exception('Failed to generate company AI briefing');
  }

  static Future<List<Map<String, dynamic>>> getCompanyContacts(String companyId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}?company_id=${Uri.encodeComponent(companyId)}'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load company contacts');
  }

  static Future<void> removeContactFromEvent(String eventId, String contactId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts/$contactId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to remove contact from event');
  }

  static Future<void> addContactToEvent(String eventId, String contactId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts'),
      headers: await _headers(),
      body: json.encode({'contact_id': contactId}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to link contact to event');
  }

  static Future<List<Map<String, dynamic>>> getEventTargetContacts(String eventId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load target contacts');
  }

  static Future<void> updateTargetContactStatus(String eventId, String contactId, String status) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts/$contactId'),
      headers: await _headers(),
      body: json.encode({'status': status}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to update target contact status');
  }

  static Future<Map<String, dynamic>> addEventTarget(String eventId, String companyId, {String priority = 'medium', String? boothLocation}) async {
    final body = <String, dynamic>{'company_id': companyId, 'priority': priority};
    if (boothLocation != null && boothLocation.isNotEmpty) body['booth_location'] = boothLocation;
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets'),
      headers: await _headers(),
      body: json.encode(body),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to add target');
  }

  static Future<void> deleteEventTarget(String eventId, String targetId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to remove target');
  }

  static Future<Map<String, dynamic>> createCompany(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}'),
      headers: await _headers(),
      body: json.encode(data),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = json.decode(response.body);
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create company');
  }

  static Future<Map<String, dynamic>> importEventTargets(String eventId, Uint8List fileBytes, String fileName) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/import');
    final request = http.MultipartRequest('POST', uri);
    final hdrs = await _headers();
    if (hdrs.containsKey('Authorization')) {
      request.headers['Authorization'] = hdrs['Authorization']!;
    }
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      final data = json.decode(body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Import failed');
  }

  static Future<Map<String, dynamic>> importContacts(Uint8List fileBytes, String fileName) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/import');
    final request = http.MultipartRequest('POST', uri);
    final hdrs = await _headers();
    if (hdrs.containsKey('Authorization')) {
      request.headers['Authorization'] = hdrs['Authorization']!;
    }
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      final data = json.decode(body);
      return data as Map<String, dynamic>;
    }
    throw Exception('Import failed');
  }

  static Future<Map<String, dynamic>> generateTargetBriefing(String eventId, String targetId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/briefing'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to generate briefing');
  }

  static Future<void> updateEventTarget(String eventId, String targetId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
      body: json.encode(data),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to update target');
  }

  static Future<List<Map<String, dynamic>>> getTargetContacts(String eventId, String targetId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/contacts'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load contacts');
  }

  static Future<void> linkContactToTarget(String eventId, String targetId, String contactId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/contacts'),
      headers: await _headers(),
      body: json.encode({'contact_id': contactId}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to link contact');
  }

  static Future<void> unlinkContactFromTarget(String eventId, String targetId, String contactId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/contacts/$contactId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to unlink contact');
  }

  static Future<Map<String, dynamic>> getLiveEventData(String eventId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/live'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load live event data');
  }

  static Future<Event> getOngoingEvent() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/ongoing/current'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    }
    throw Exception('No ongoing event found');
  }

  /// Single-round-trip replacement for getOngoingEvent + getLiveEventData + a captures fetch.
  /// Returns null if no ongoing event. On success, returns a map with keys:
  ///   'event' (Event), 'liveData' (Map), 'captures' (List), 'nextEvent' (Event?)
  static Future<Map<String, dynamic>?> getLiveSession() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/live-session'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 404) {
      final body = json.decode(response.body);
      final nextRaw = body['nextEvent'];
      return {'event': null, 'nextEvent': nextRaw != null ? Event.fromJson(nextRaw) : null};
    }
    if (response.statusCode == 200) {
      final body = json.decode(response.body)['data'] as Map<String, dynamic>;
      return {
        'event': Event.fromJson(body['event'] as Map<String, dynamic>),
        'liveData': body['liveData'] as Map<String, dynamic>,
        'captures': (body['captures'] as List).cast<Map<String, dynamic>>(),
        'nextEvent': null,
      };
    }
    throw Exception('Failed to load live session');
  }

  static Future<Event> getNextUpcomingEvent() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/upcoming/next'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    }
    throw Exception('No upcoming event found');
  }

  static Future<Map<String, dynamic>> createEventGoal(
      String eventId, String label, int total) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals'),
      headers: await _headers(),
      body: json.encode({'label': label, 'total': total}),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
    }
    throw Exception('Failed to create goal');
  }

  static Future<Map<String, dynamic>> updateEventGoal(
      String eventId, String goalId, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals/$goalId'),
      headers: await _headers(),
      body: json.encode(data),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
    }
    throw Exception('Failed to update goal');
  }

  static Future<void> deleteEventGoal(String eventId, String goalId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals/$goalId'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to delete goal');
  }

  static Future<void> updateTargetStatus(String eventId, String targetId, String status) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to update target status');
  }

  static Future<List<Map<String, dynamic>>> getEventGoals(String eventId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals'),
      headers: await _headers(),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to load goals');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  static Future<String> askEventQuestion(String eventId, String question) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/ask'),
      headers: await _headers(),
      body: jsonEncode({'question': question}),
    );
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to get AI answer');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['answer'] as String? ?? '';
  }

  static Future<String> transcribeAudio(String base64Audio) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ai}/transcribe'),
      headers: await _headers(),
      body: json.encode({'audio_data': base64Audio}),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['transcript'] as String? ?? '';
    }
    throw Exception('Failed to transcribe audio');
  }

  static Future<Map<String, dynamic>> createCapture({
    required String captureType,
    String? imageData,
    String? rawText,
    Map<String, dynamic>? extractedData,
    String? eventId,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{'capture_type': captureType};
    if (imageData != null) body['image'] = imageData;
    if (rawText != null) body['raw_text'] = rawText;
    if (extractedData != null) body['extracted_data'] = extractedData;
    if (eventId != null) body['event_id'] = eventId;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.captures}'),
      headers: await _headersWithKey(idempotencyKey),
      body: json.encode(body),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 409) {
      // Idempotent replay — return existing record.
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'Failed to create capture (${response.statusCode}): ${response.body}',
    );
  }

  static Future<Map<String, dynamic>> checkDuplicateContacts({
    String? name,
    String? email,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/check-duplicate'),
      headers: await _headers(),
      body: json.encode(body),
    );
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to check duplicates');
  }

  /// Delta sync — see backend/src/routes/sync.ts. `since` is the previous
  /// `server_time` (omit/null for a full snapshot). `tables` is a CSV of
  /// synced table names (omit for all of them, including `companies`).
  static Future<Map<String, dynamic>> getSyncDelta({
    String? since,
    String? tables,
  }) async {
    final query = <String, String>{
      'since': ?since,
      'tables': ?tables,
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sync}')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: await _headers());
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch sync delta');
  }
}
