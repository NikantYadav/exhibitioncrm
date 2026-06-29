import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/contact.dart';
import '../models/event.dart';
import 'auth_service.dart';

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class RateLimitException implements Exception {
  final int retryAfterSeconds;
  const RateLimitException(this.retryAfterSeconds);
}

/// Thrown when an event's time window overlaps an existing event (backend 409).
class EventOverlapException implements Exception {
  final String message;
  const EventOverlapException(this.message);
}

/// Thrown for a backend 400 carrying a plain user-facing validation message
/// (e.g. "Event start date cannot be in the past."), so the UI can show it.
class EventValidationException implements Exception {
  final String message;
  const EventValidationException(this.message);
}

class ApiService {
  /// Called when the session can no longer be recovered (refresh failed).
  /// Set by AuthProvider on init. Triggers logout.
  static void Function()? onUnauthorized;

  /// Called with a fresh access token whenever a refresh succeeds, so the
  /// AuthProvider can update its in-memory token and realtime auth.
  static void Function(String accessToken)? onTokenRefreshed;

  /// De-duplicates concurrent refresh attempts: if several requests hit a 401
  /// at once, they all await the same refresh instead of racing.
  static Future<bool>? _refreshInFlight;

  static void checkRateLimit(http.Response response) {
    if (response.statusCode == 429) {
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
      throw RateLimitException(retryAfter);
    }
  }

  static void checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw const UnauthorizedException();
    }
  }

  /// Builds the exception thrown on a failed API call. The full raw response
  /// body (Zod validation JSON, stack-trace-ish server text, etc.) is logged to
  /// the console for debugging, while the [Exception] message kept for the UI is
  /// a short, user-friendly sentence — never the raw backend payload.
  ///
  /// [action] is a human phrase like 'save this interaction' used to form the
  /// message: "Couldn't [action]. Please try again."
  static Exception _apiError(String action, http.Response response) {
    debugPrint(
      '[ApiService] $action failed (${response.statusCode}): ${response.body}',
    );
    return Exception("Couldn't $action. Please try again.");
  }

  /// Attempt to refresh the access token using the stored refresh token.
  /// Returns true if a fresh token was obtained and persisted. Concurrent
  /// callers share a single in-flight refresh.
  static Future<bool> _tryRefreshToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<bool> _doRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final result = await AuthService.refresh(refreshToken);
    if (result['success'] != true) return false;

    final session = result['session'] as Map<String, dynamic>?;
    final newAccess = session?['access_token'] as String?;
    final newRefresh = session?['refresh_token'] as String?;
    if (newAccess == null || newAccess.isEmpty) return false;

    await prefs.setString('access_token', newAccess);
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await prefs.setString('refresh_token', newRefresh);
    }
    onTokenRefreshed?.call(newAccess);
    return true;
  }

  /// Sends a request, and on a 401 transparently refreshes the access token
  /// once and retries. Only if the refresh fails does it surface as a 401
  /// (triggering logout via [checkUnauthorized]). [send] is a closure so it can
  /// be re-invoked with fresh auth headers on retry.
  static Future<http.Response> _send(
    Future<http.Response> Function() send,
  ) async {
    var response = await send();
    if (response.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        response = await send();
      }
    }
    return response;
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

  static Future<List<Contact>> getContacts({String? query}) async {
    final url = query != null && query.isNotEmpty
        ? '${ApiConfig.baseUrl}${ApiConfig.contacts}?q=${Uri.encodeComponent(query)}'
        : '${ApiConfig.baseUrl}${ApiConfig.contacts}';
    final response = await _send(() async => http.get(
      Uri.parse(url),
      headers: await _headers(),
    ));

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
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$id'),
      headers: await _headers(),
    ));
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
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}'),
      headers: await _headersWithKey(idempotencyKey),
      body: json.encode(contactData),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return Contact.fromJson(data['data']);
    } else if (response.statusCode == 409) {
      // Idempotent replay — return existing contact.
      final data = json.decode(response.body);
      return Contact.fromJson(data['data']);
    } else {
      throw _apiError('save this contact', response);
    }
  }

  static Future<List<Event>> getEvents({String? query}) async {
    final url = query != null && query.isNotEmpty
        ? '${ApiConfig.baseUrl}${ApiConfig.events}?q=${Uri.encodeComponent(query)}'
        : '${ApiConfig.baseUrl}${ApiConfig.events}';
    final response = await _send(() async => http.get(
      Uri.parse(url),
      headers: await _headers(),
    ));

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
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    } else {
      throw Exception('Failed to load event');
    }
  }

  static Future<List<Map<String, dynamic>>> getContactTimeline(String contactId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/timeline'),
      headers: await _headers(),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load contact timeline');
    }
  }

  /// Returns a short-lived signed URL for the contact's scanned/uploaded card
  /// image, or null if the contact has no card.
  static Future<String?> getContactCardUrl(String contactId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/card-url'),
      headers: await _headers(),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']?['url'] as String?;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load card image');
    }
  }

  static Future<Event> createEvent(
    Map<String, dynamic> eventData, {
    String? idempotencyKey,
  }) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}'),
      headers: await _headersWithKey(idempotencyKey),
      body: json.encode(eventData),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    } else if (response.statusCode == 409) {
      throw EventOverlapException(
        _stringError(response) ?? 'This event overlaps another event. Choose a non-overlapping time.',
      );
    } else if (response.statusCode == 400) {
      final msg = _stringError(response);
      if (msg != null) throw EventValidationException(msg);
      throw _apiError('save this event', response);
    } else {
      throw _apiError('save this event', response);
    }
  }

  /// Returns the backend's `error` field when it is a plain, user-safe string
  /// (our hand-written validation messages). Zod errors are objects, not
  /// strings, so they return null and stay hidden behind the generic message.
  static String? _stringError(http.Response response) {
    try {
      final body = json.decode(response.body);
      final msg = body['error'];
      if (msg is String && msg.isNotEmpty) return msg;
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> analyzeCard(String imageData) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ai}/analyze-card'),
      headers: await _headers(),
      body: json.encode({'image': imageData}),
    ));

    checkUnauthorized(response);
    checkRateLimit(response);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw _apiError('analyze this card', response);
    }
  }

  static Future<Map<String, dynamic>> getAllFollowUps() async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}/follow-ups'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load follow-ups');
  }

  static Future<Map<String, dynamic>> getDashboardPriorities() async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}/dashboard/priorities'),
      headers: await _headers(),
    ));
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

    final response = await _send(() async => http.get(
      Uri.parse(url),
      headers: await _headers(),
    ));

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
    final response = await _send(() async => http.get(
      Uri.parse(url),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to search messages');
  }

  static Future<List<Map<String, dynamic>>> listConversations() async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}'),
      headers: await _headers(),
    ));
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

    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}'),
      headers: await _headers(),
      body: json.encode(body),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create conversation');
  }

  /// Create a user message up front (so files can be attached to it before the
  /// assistant turn runs). Returns the created message map (with its id).
  static Future<Map<String, dynamic>> createUserMessage({
    required String conversationId,
    required String content,
  }) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}/$conversationId/messages'),
      headers: await _headers(),
      body: json.encode({'content': content}),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return (json.decode(response.body)['data']) as Map<String, dynamic>;
    }
    final body = json.decode(response.body);
    throw Exception(body is Map && body['error'] != null ? body['error'] : 'Failed to create message');
  }

  /// Upload a document/photo to a chat message. Server stores it, extracts text,
  /// and (for large docs) chunks+embeds it. Returns the attachment map including
  /// `id`, `extraction_status`, and `token_estimate`.
  static Future<Map<String, dynamic>> uploadChatAttachment({
    required String conversationId,
    required String messageId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}/$conversationId/attachments/upload');
    final request = http.MultipartRequest('POST', uri);
    final hdrs = await _headers();
    if (hdrs.containsKey('Authorization')) {
      request.headers['Authorization'] = hdrs['Authorization']!;
    }
    request.fields['message_id'] = messageId;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: _contentTypeFor(fileName),
    ));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 200) {
      return (json.decode(body)['data']) as Map<String, dynamic>;
    }
    final decoded = json.decode(body);
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Upload failed');
  }

  // Best-effort content type from a filename extension, so uploads are stored
  // with a real mime (not application/octet-stream) and render as images.
  static MediaType? _contentTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return null;
    const map = {
      'jpg': ['image', 'jpeg'], 'jpeg': ['image', 'jpeg'], 'png': ['image', 'png'],
      'webp': ['image', 'webp'], 'gif': ['image', 'gif'], 'heic': ['image', 'heic'],
      'pdf': ['application', 'pdf'], 'csv': ['text', 'csv'],
      'doc': ['application', 'msword'],
      'docx': ['application', 'vnd.openxmlformats-officedocument.wordprocessingml.document'],
      'xls': ['application', 'vnd.ms-excel'],
      'xlsx': ['application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
      'ppt': ['application', 'vnd.ms-powerpoint'],
      'pptx': ['application', 'vnd.openxmlformats-officedocument.presentationml.presentation'],
    };
    final type = map[fileName.substring(dot + 1).toLowerCase()];
    return type == null ? null : MediaType(type[0], type[1]);
  }

  static Future<Map<String, dynamic>> assistantRespond({
    required String conversationId,
    required String text,
    bool researchMode = false,
    String? userMessageId,
    List<String>? attachmentIds,
    List<Map<String, dynamic>> mentions = const [],
  }) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assistant}/respond'),
      headers: await _headers(),
      body: json.encode({
        'conversation_id': conversationId,
        'text': text,
        if (researchMode) 'research_mode': true,
        'user_message_id': ?userMessageId,
        if (attachmentIds != null && attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
        if (mentions.isNotEmpty) 'mentions': mentions,
      }),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final body = json.decode(response.body);
    throw Exception(body is Map && body['error'] != null ? body['error'] : 'Assistant error');
  }

  /// Approve or deny a pending write the assistant proposed. [decision] is
  /// 'approve' or 'deny'. Returns the same shape as [assistantRespond] — either
  /// a completed turn (assistant_message) or another awaiting_permission action.
  static Future<Map<String, dynamic>> assistantResume({
    required String pendingActionId,
    required String decision,
  }) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assistant}/resume'),
      headers: await _headers(),
      body: json.encode({
        'pending_action_id': pendingActionId,
        'decision': decision,
      }),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    final body = json.decode(response.body);
    throw Exception(body is Map && body['error'] != null ? body['error'] : 'Assistant error');
  }

  /// The latest unresolved write awaiting permission for a conversation, or null.
  /// Used to restore the confirmation card after the app was backgrounded mid-turn.
  static Future<Map<String, dynamic>?> assistantPending(String conversationId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assistant}/pending?conversation_id=$conversationId'),
      headers: await _headers(),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return body['pending_action'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<void> deleteConversation(String conversationId) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversations}/$conversationId'),
      headers: await _headers(),
    ));

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
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}/emails/draft'),
      headers: await _headers(),
      body: json.encode({
        'contact_id': contactId,
        'event_id': eventId,
        'email_type': emailType,
        'custom_context': customContext,
      }),
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to generate email draft');
  }

  /// Returns the updated contact row from the server (the full record),
  /// so callers can apply it to the local cache optimistically.
  static Future<Map<String, dynamic>> updateContact(String contactId, Map<String, dynamic> data) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId'),
      headers: await _headers(),
      body: json.encode(data),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update contact');
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getContactEvents(String contactId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/events'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    throw Exception('Failed to load contact events');
  }

  static Future<void> linkContactToEvent(String contactId, String eventId) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/events'),
      headers: await _headers(),
      body: json.encode({'event_id': eventId}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to link event');
  }

  static Future<void> unlinkContactFromEvent(String contactId, String eventId) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/events/$eventId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to unlink event');
  }

  static Future<Map<String, dynamic>> getEventStats(String eventId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/stats'),
      headers: await _headers(),
    ));
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
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/stats/batch?ids=$ids'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final raw = json.decode(response.body)['data'] as Map<String, dynamic>;
      return raw.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
    }
    throw Exception('Failed to load batch event stats');
  }

  static Future<Map<String, dynamic>> getEventTarget(String eventId, String targetId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load event target');
  }

  static Future<List<Map<String, dynamic>>> getEventTargets(String eventId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets'),
      headers: await _headers(),
    ));
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
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId'),
      headers: await _headers(),
      body: json.encode({
        'action': 'send',
        'subject': ?subject,
        'body': ?body,
      }),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to mark follow-up as sent');
    }
  }

  /// Set a contact's follow-up status on the global queue. When [eventId] is
  /// omitted, applies to ALL of the contact's records (the collapsed home card
  /// flips as a unit); pass [eventId] (or null explicitly) to target one record.
  static Future<void> setFollowUpStatus(
    String contactId,
    String status, {
    String? eventId,
    bool scopeToEvent = false,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (scopeToEvent) body['event_id'] = eventId;
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}/follow-ups/contact/$contactId'),
      headers: await _headers(),
      body: json.encode(body),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update follow-up status');
    }
  }

  /// Toggle a contact's priority. With [eventId], flips the per-event
  /// follow_ups.is_priority (event queue); without it, flips the global
  /// contacts.is_priority (global queue). Mirrors the split priority model.
  static Future<void> setContactPriority(
    String contactId,
    bool isPriority, {
    String? eventId,
  }) async {
    final body = <String, dynamic>{'is_priority': isPriority};
    if (eventId != null) body['event_id'] = eventId;
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}/follow-ups/contact/$contactId/priority'),
      headers: await _headers(),
      body: json.encode(body),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update priority');
    }
  }

  static Future<void> unskipFollowUp(String eventId, String contactId) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId'),
      headers: await _headers(),
      body: json.encode({'action': 'unskip'}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to unskip follow-up');
    }
  }

  static Future<void> skipFollowUp(String eventId, String contactId) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId'),
      headers: await _headers(),
      body: json.encode({'action': 'skip'}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to skip follow-up');
    }
  }

  static Future<Map<String, String>> generateFollowUpDraft(
      String eventId, String contactId) async {
    final response = await _send(() async => http.post(
      Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/follow-ups/$contactId/draft'),
      headers: await _headers(),
    ));
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
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete event');
    }
  }

  static Future<Event> updateEvent(String eventId, Map<String, dynamic> data) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId'),
      headers: await _headers(),
      body: json.encode(data),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return Event.fromJson(body['data']);
    } else if (response.statusCode == 409) {
      throw EventOverlapException(
        _stringError(response) ?? 'This event overlaps another event. Choose a non-overlapping time.',
      );
    } else if (response.statusCode == 400) {
      final msg = _stringError(response);
      if (msg != null) throw EventValidationException(msg);
    }
    throw Exception('Failed to update event');
  }

  static Future<void> deleteContact(String contactId) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete contact');
    }
  }

  static Future<Map<String, dynamic>> getContactInsights(String contactId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/$contactId/insights'),
      headers: await _headers(),
    ));
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
    final response = await _send(() async => http.post(
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
    ));

    checkUnauthorized(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw _apiError('save this interaction', response);
  }

  static Future<void> updateInteraction(String id, Map<String, dynamic> updates) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}/interactions/$id'),
      headers: await _headers(),
      body: json.encode(updates),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to update interaction');
    }
  }

  static Future<void> deleteInteraction(String id) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}/interactions/$id'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete interaction');
    }
  }

  static Future<List<Map<String, dynamic>>> getCompanies({String? query}) async {
    final url = query != null && query.isNotEmpty
        ? '${ApiConfig.baseUrl}${ApiConfig.companies}?q=${Uri.encodeComponent(query)}'
        : '${ApiConfig.baseUrl}${ApiConfig.companies}';
    final response = await _send(() async => http.get(Uri.parse(url), headers: await _headers()));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load companies');
  }

  static Future<Map<String, dynamic>> getCompany(String companyId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}/$companyId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load company');
  }

  static Future<Map<String, dynamic>> patchCompany(String id, Map<String, dynamic> data) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}/$id'),
      headers: await _headers(),
      body: json.encode(data),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    throw Exception(json.decode(response.body)['error'] ?? 'Failed to update company');
  }

  static Future<Map<String, dynamic>> enrichCompany(String id, {bool force = false}) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}/$id/enrich'),
      headers: await _headers(),
      body: force ? json.encode({'force': true}) : null,
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'] as Map<String, dynamic>;
    }
    throw Exception(json.decode(response.body)['error'] ?? 'Failed to enrich company');
  }

  static Future<List<String>> generateCompanyBriefing(String id, {String? notes, String? focus}) async {
    final body = <String, dynamic>{};
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();
    if (focus != null && focus.trim().isNotEmpty) body['focus'] = focus.trim();
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}/$id/briefing'),
      headers: await _headers(),
      body: body.isNotEmpty ? json.encode(body) : null,
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      return (data['talking_points'] as List).cast<String>();
    }
    throw Exception('Failed to generate company AI briefing');
  }

  static Future<List<Map<String, dynamic>>> getCompanyContacts(String companyId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}?company_id=${Uri.encodeComponent(companyId)}'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load company contacts');
  }

  static Future<void> removeContactFromEvent(String eventId, String contactId) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts/$contactId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to remove contact from event');
  }

  static Future<void> addContactToEvent(String eventId, String contactId) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts'),
      headers: await _headers(),
      body: json.encode({'contact_id': contactId}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to link contact to event');
  }

  static Future<List<Map<String, dynamic>>> getEventTargetContacts(String eventId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load target contacts');
  }

  static Future<void> updateTargetContactStatus(String eventId, String contactId, String status) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/contacts/$contactId'),
      headers: await _headers(),
      body: json.encode({'status': status}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to update target contact status');
  }

  /// Per-user "met" toggle for a company target. Separate from the shared
  /// target status and from contact follow-ups.
  static Future<void> updateTargetCompanyMet(String eventId, String targetId, bool met) async {
    final response = await _send(() async => http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/met'),
      headers: await _headers(),
      body: json.encode({'met': met}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to update company met status');
  }

  static Future<Map<String, dynamic>> addEventTarget(String eventId, String companyId, {String priority = 'medium', String? boothLocation}) async {
    final body = <String, dynamic>{'company_id': companyId, 'priority': priority};
    if (boothLocation != null && boothLocation.isNotEmpty) body['booth_location'] = boothLocation;
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets'),
      headers: await _headers(),
      body: json.encode(body),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to add target');
  }

  static Future<void> deleteEventTarget(String eventId, String targetId) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to remove target');
  }

  static Future<Map<String, dynamic>> createCompany(Map<String, dynamic> data) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.companies}'),
      headers: await _headers(),
      body: json.encode(data),
    ));
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
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/briefing'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to generate briefing');
  }

  static Future<void> updateEventTarget(String eventId, String targetId, Map<String, dynamic> data) async {
    final response = await _send(() async => http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
      body: json.encode(data),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to update target');
  }

  static Future<List<Map<String, dynamic>>> getTargetContacts(String eventId, String targetId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/contacts'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load contacts');
  }

  static Future<void> linkContactToTarget(String eventId, String targetId, String contactId) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/contacts'),
      headers: await _headers(),
      body: json.encode({'contact_id': contactId}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to link contact');
  }

  static Future<void> unlinkContactFromTarget(String eventId, String targetId, String contactId) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId/contacts/$contactId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to unlink contact');
  }

  static Future<Map<String, dynamic>> getLiveEventData(String eventId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/live'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to load live event data');
  }

  static Future<Event> getOngoingEvent() async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/ongoing/current'),
      headers: await _headers(),
    ));
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
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/live-session'),
      headers: await _headers(),
    ));
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
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/upcoming/next'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Event.fromJson(data['data']);
    }
    throw Exception('No upcoming event found');
  }

  static Future<Map<String, dynamic>> createEventGoal(
      String eventId, String label, int total) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals'),
      headers: await _headers(),
      body: json.encode({'label': label, 'total': total}),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
    }
    throw Exception('Failed to create goal');
  }

  static Future<Map<String, dynamic>> updateEventGoal(
      String eventId, String goalId, Map<String, dynamic> data) async {
    final response = await _send(() async => http.patch(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals/$goalId'),
      headers: await _headers(),
      body: json.encode(data),
    ));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return (json.decode(response.body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
    }
    throw Exception('Failed to update goal');
  }

  static Future<void> deleteEventGoal(String eventId, String goalId) async {
    final response = await _send(() async => http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals/$goalId'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to delete goal');
  }

  static Future<void> updateTargetStatus(String eventId, String targetId, String status) async {
    final response = await _send(() async => http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/targets/$targetId'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to update target status');
  }

  static Future<List<Map<String, dynamic>>> getEventGoals(String eventId) async {
    final response = await _send(() async => http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/goals'),
      headers: await _headers(),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to load goals');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List);
  }

  static Future<String> askEventQuestion(String eventId, String question) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.events}/$eventId/ask'),
      headers: await _headers(),
      body: jsonEncode({'question': question}),
    ));
    checkUnauthorized(response);
    if (response.statusCode != 200) throw Exception('Failed to get AI answer');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['answer'] as String? ?? '';
  }

  static Future<String> transcribeAudio(String base64Audio, {int? durationSeconds}) async {
    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ai}/transcribe'),
      headers: await _headers(),
      body: json.encode({
        'audio_data': base64Audio,
        'duration_seconds': ?durationSeconds,
      }),
    ));
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
    String? meetingContext,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{'capture_type': captureType};
    if (imageData != null) body['image'] = imageData;
    if (rawText != null) body['raw_text'] = rawText;
    if (extractedData != null) body['extracted_data'] = extractedData;
    if (eventId != null) body['event_id'] = eventId;
    if (meetingContext != null && meetingContext.isNotEmpty) body['meeting_context'] = meetingContext;

    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.captures}'),
      headers: await _headersWithKey(idempotencyKey),
      body: json.encode(body),
    ));
    checkUnauthorized(response);
    checkRateLimit(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 409) {
      // Idempotent replay — return existing record.
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw _apiError('save this capture', response);
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

    final response = await _send(() async => http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contacts}/check-duplicate'),
      headers: await _headers(),
      body: json.encode(body),
    ));
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
    final response = await _send(() async => http.get(uri, headers: await _headers()));
    checkUnauthorized(response);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch sync delta');
  }
}
