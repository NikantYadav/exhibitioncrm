import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<MessageLink> links;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.links = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'] as List<dynamic>? ?? [];
    return ChatMessage(
      id: json['id'] as String,
      text: (json['content'] ?? '') as String,
      isUser: json['sender_type'] == 'user',
      timestamp:
          DateTime.tryParse((json['created_at'] ?? '') as String) ??
              DateTime.now(),
      links: rawLinks
          .cast<Map<String, dynamic>>()
          .map(MessageLink.fromJson)
          .toList(),
    );
  }
}

class MessageLink {
  final String id;
  final String? contactId;
  final String? eventId;
  final String? reminderId;
  final String? emailDraftId;

  MessageLink({
    required this.id,
    this.contactId,
    this.eventId,
    this.reminderId,
    this.emailDraftId,
  });

  factory MessageLink.fromJson(Map<String, dynamic> json) {
    return MessageLink(
      id: json['id'] as String,
      contactId: json['contact_id'] as String?,
      eventId: json['event_id'] as String?,
      reminderId: json['reminder_id'] as String?,
      emailDraftId: json['email_draft_id'] as String?,
    );
  }

  bool get hasAnyLink =>
      contactId != null ||
      eventId != null ||
      reminderId != null ||
      emailDraftId != null;
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = {};
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  bool _hasMore = true;
  String? _nextBefore;
  String? _error;
  String? _conversationId;
  RealtimeChannel? _channel;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get conversationId => _conversationId;

  Future<void> loadConversation(String conversationId,
      {String? accessToken}) async {
    if (_conversationId == conversationId) return;

    // Tear down old subscription
    await _channel?.unsubscribe();
    _channel = null;

    _conversationId = conversationId;
    _messages.clear();
    _messageIds.clear();
    _nextBefore = null;
    _hasMore = true;
    _error = null;
    notifyListeners();

    await _loadHistory();

    // Set realtime auth
    if (accessToken != null) {
      try {
        Supabase.instance.client.realtime.setAuth(accessToken);
      } catch (_) {}
    }

    _subscribeRealtime(conversationId);
  }

  Future<void> _loadHistory() async {
    if (_conversationId == null || _isLoadingHistory) return;
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final result = await ApiService.getMessages(
        _conversationId!,
        limit: 50,
        before: _nextBefore,
      );
      final msgs = result['data'] as List<Map<String, dynamic>>;
      final nextBefore = result['next_before'] as String?;

      // msgs are in ascending order (oldest first)
      final newMessages = <ChatMessage>[];
      for (final m in msgs) {
        final id = m['id'] as String;
        if (!_messageIds.contains(id)) {
          _messageIds.add(id);
          newMessages.add(ChatMessage.fromJson(m));
        }
      }

      if (_nextBefore == null) {
        // Initial load — prepend welcome if empty
        _messages.insertAll(0, newMessages);
        if (_messages.isEmpty) {
          _messages.add(ChatMessage(
            id: 'welcome',
            text:
                "Hi! I'm your AI assistant. Ask me to create contacts, plan exhibitions, set follow-ups, or draft emails.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
      } else {
        // Load-more — prepend older messages
        _messages.insertAll(0, newMessages);
      }

      _nextBefore = nextBefore;
      _hasMore = msgs.length >= 50 && nextBefore != null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingHistory || _nextBefore == null) return;
    await _loadHistory();
  }

  void _subscribeRealtime(String conversationId) {
    _channel = Supabase.instance.client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final id = record['id'] as String?;
            if (id == null || _messageIds.contains(id)) return;
            _messageIds.add(id);
            _messages.add(ChatMessage(
              id: id,
              text: (record['content'] ?? '') as String,
              isUser: record['sender_type'] == 'user',
              timestamp:
                  DateTime.tryParse((record['created_at'] ?? '') as String) ??
                      DateTime.now(),
            ));
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String text) async {
    if (_conversationId == null || text.trim().isEmpty) return;

    _isTyping = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await ApiService.assistantRespond(
        conversationId: _conversationId!,
        text: text.trim(),
      );

      // Upsert user + assistant messages from response
      void upsert(Map<String, dynamic>? msg) {
        if (msg == null) return;
        final id = msg['id'] as String?;
        if (id == null || _messageIds.contains(id)) return;
        _messageIds.add(id);
        _messages.add(ChatMessage.fromJson(msg));
      }

      upsert(resp['user_message'] as Map<String, dynamic>?);
      upsert(resp['assistant_message'] as Map<String, dynamic>?);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void reset() {
    _channel?.unsubscribe();
    _channel = null;
    _conversationId = null;
    _messages.clear();
    _messageIds.clear();
    _nextBefore = null;
    _hasMore = true;
    _error = null;
    _isTyping = false;
    notifyListeners();
  }
}
