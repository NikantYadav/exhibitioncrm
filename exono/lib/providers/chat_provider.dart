import 'dart:convert';
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
  final bool researchMode;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.linkedEntities = const [],
    this.researchMode = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {List<LinkedEntity> linkedEntities = const []}) {
    return ChatMessage(
      id: json['id'] as String,
      text: (json['content'] ?? '') as String,
      isUser: json['sender_type'] == 'user',
      timestamp:
          (DateTime.tryParse((json['created_at'] ?? '') as String) ?? DateTime.now()).toLocal(),
      linkedEntities: linkedEntities,
      researchMode: json['research_mode'] == true,
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
  String? _failedMessageId;
  // Text + mode of the last failed send, kept so a retry works even if the
  // optimistic bubble was cleared (e.g. failure during first-send convo creation).
  String? _failedText;
  bool _failedResearch = false;
  RealtimeChannel? _channel;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get hasMore => _hasMore;
  String? get failedMessageId => _failedMessageId;
  String? get failedText => _failedText;
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
          final rawEntities = _parseLinkedEntities(m['linked_entities']);
          final entities = rawEntities.map(LinkedEntity.fromJson).toList();
          newMessages.add(ChatMessage.fromJson(m, linkedEntities: entities));
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

            if (record['sender_type'] == 'user') {
              // Ignore the realtime echo of a user message that we still have an
              // optimistic bubble for (matched by content). The send's success
              // path swaps the optimistic bubble for the real record explicitly;
              // on failure the backend rolls the user message back, so the
              // optimistic bubble must survive to carry the inline retry. This is
              // matched by text (not _isTyping) so it holds for concurrent sends.
              final content = (record['content'] ?? '') as String;
              final hasOptimistic = _messages.any(
                (m) => m.id.startsWith('optimistic_') && m.text == content,
              );
              if (hasOptimistic) {
                _messageIds.remove(id);
                return;
              }
            } else if (record['sender_type'] == 'assistant') {
              _isTyping = false;
            }

            _insertOrdered(ChatMessage(
              id: id,
              text: (record['content'] ?? '') as String,
              isUser: record['sender_type'] == 'user',
              timestamp:
                  (DateTime.tryParse((record['created_at'] ?? '') as String) ??
                          DateTime.now())
                      .toLocal(),
            ));
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<Map<String, dynamic>?> sendMessage(String text, {bool researchMode = false}) async {
    if (_conversationId == null || text.trim().isEmpty) return null;

    // --- Optimistic user message ---
    final optimisticId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = ChatMessage(
      id: optimisticId,
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      researchMode: researchMode,
    );
    _messageIds.add(optimisticId);
    _insertOrdered(optimisticMsg);
    _isTyping = true;
    _error = null;
    _failedMessageId = null;
    notifyListeners();

    try {
      final resp = await ApiService.assistantRespond(
        conversationId: _conversationId!,
        text: text.trim(),
        researchMode: researchMode,
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
          _insertOrdered(newMsg);
        }
      }

      upsert(resp['user_message'] as Map<String, dynamic>?);
      upsert(resp['assistant_message'] as Map<String, dynamic>?,
          linkedEntities: parsedLinkedEntities);

      return resp['conversation'] as Map<String, dynamic>?;
    } catch (_) {
      _error = 'Failed to send message. Please try again.';
      _failedText = text.trim();
      _failedResearch = researchMode;
      // The optimistic bubble is kept (realtime echo is ignored while in flight,
      // and the backend rolls the user message back on failure), so the failure
      // marker reliably points to it and the inline retry shows on the bubble.
      _failedMessageId = optimisticId;
      return null;
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // Insert keeping _messages sorted ascending by timestamp, so concurrent sends
  // and out-of-order realtime arrivals never interleave (e.g. response #1
  // landing after optimistic message #2). Ties keep insertion order (stable).
  void _insertOrdered(ChatMessage msg) {
    var i = _messages.length;
    while (i > 0 && _messages[i - 1].timestamp.isAfter(msg.timestamp)) {
      i--;
    }
    _messages.insert(i, msg);
  }

  // Supabase may return jsonb columns as a pre-serialized String instead of a List.
  static List<Map<String, dynamic>> _parseLinkedEntities(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    return const [];
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
    _failedMessageId = null;
    _failedText = null;
    _isTyping = false;
    _isLoadingHistory = loading;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> retryFailedMessage() async {
    // Prefer the failed bubble's text; fall back to the stored failed text so a
    // retry still works when the optimistic bubble didn't survive the failure.
    String? text = _failedText;
    bool research = _failedResearch;
    if (_failedMessageId != null) {
      final idx = _messages.indexWhere((m) => m.id == _failedMessageId);
      if (idx != -1) {
        text = _messages[idx].text;
        research = _messages[idx].researchMode;
        // Remove the stuck optimistic message before re-sending
        _messages.removeAt(idx);
        _messageIds.remove(_failedMessageId);
      }
    }
    if (text == null || text.trim().isEmpty) return null;

    _failedMessageId = null;
    _failedText = null;
    _error = null;
    notifyListeners();
    return sendMessage(text, researchMode: research);
  }
}
