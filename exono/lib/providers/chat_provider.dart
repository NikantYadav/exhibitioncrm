import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/linked_entity.dart';
import '../services/api_service.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<LinkedEntity> linkedEntities;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.linkedEntities = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {List<LinkedEntity> linkedEntities = const []}) {
    return ChatMessage(
      id: json['id'] as String,
      text: (json['content'] ?? '') as String,
      isUser: json['sender_type'] == 'user',
      timestamp:
          DateTime.tryParse((json['created_at'] ?? '') as String) ??
              DateTime.now(),
      linkedEntities: linkedEntities,
    );
  }
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

    await _loadHistory(force: true);

    // Set realtime auth
    if (accessToken != null) {
      try {
        Supabase.instance.client.realtime.setAuth(accessToken);
      } catch (_) {}
    }

    _subscribeRealtime(conversationId);
  }

  Future<void> _loadHistory({bool force = false}) async {
    if (_conversationId == null || (!force && _isLoadingHistory)) return;
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
        // Initial load
        _messages.insertAll(0, newMessages);
      } else {
        // Load-more — prepend older messages
        _messages.insertAll(0, newMessages);
      }

      _nextBefore = nextBefore;
      _hasMore = msgs.length >= 50 && nextBefore != null;
    } catch (_) {
      _error = 'Unable to load messages. Please try again.';
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

            if (record['sender_type'] == 'assistant') {
              _isTyping = false;
            } else if (record['sender_type'] == 'user') {
              // Swap out any pending optimistic placeholder so the real
              // server record takes its place without creating a duplicate.
              final optimisticIds = _messages
                  .where((m) => m.id.startsWith('optimistic_'))
                  .map((m) => m.id)
                  .toList();
              _messages.removeWhere((m) => m.id.startsWith('optimistic_'));
              _messageIds.removeAll(optimisticIds);
            }

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

  Future<Map<String, dynamic>?> sendMessage(String text) async {
    if (_conversationId == null || text.trim().isEmpty) return null;

    // --- Optimistic user message ---
    final optimisticId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = ChatMessage(
      id: optimisticId,
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messageIds.add(optimisticId);
    _messages.add(optimisticMsg);
    _isTyping = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await ApiService.assistantRespond(
        conversationId: _conversationId!,
        text: text.trim(),
      );

      // Remove the optimistic message and replace with the real one from server
      _messages.removeWhere((m) => m.id == optimisticId);
      _messageIds.remove(optimisticId);

      // Parse linked_entities from response
      final rawLinkedEntities = resp['linked_entities'] as List<dynamic>? ?? [];
      final parsedLinkedEntities = rawLinkedEntities
          .cast<Map<String, dynamic>>()
          .map(LinkedEntity.fromJson)
          .toList();

      // Upsert messages — if already added by realtime, replace to attach linkedEntities.
      void upsert(Map<String, dynamic>? msg, {List<LinkedEntity> linkedEntities = const []}) {
        if (msg == null) return;
        final id = msg['id'] as String?;
        if (id == null) return;
        final newMsg = ChatMessage.fromJson(msg, linkedEntities: linkedEntities);
        final idx = _messages.indexWhere((m) => m.id == id);
        if (idx != -1) {
          _messages[idx] = newMsg;
        } else {
          _messageIds.add(id);
          _messages.add(newMsg);
        }
      }

      upsert(resp['user_message'] as Map<String, dynamic>?);
      upsert(resp['assistant_message'] as Map<String, dynamic>?,
          linkedEntities: parsedLinkedEntities);

      return resp['conversation'] as Map<String, dynamic>?;
    } catch (_) {
      // Keep optimistic message visible but mark error
      _error = 'Failed to send message. Please try again.';
      return null;
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

  void reset({bool loading = true}) {
    _channel?.unsubscribe();
    _channel = null;
    _conversationId = null;
    _messages.clear();
    _messageIds.clear();
    _nextBefore = null;
    _hasMore = true;
    _error = null;
    _isTyping = false;
    _isLoadingHistory = loading;
    notifyListeners();
  }
}
