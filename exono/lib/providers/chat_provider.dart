import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_attachment.dart';
import '../models/linked_entity.dart';
import '../services/api_service.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<LinkedEntity> linkedEntities;
  final bool researchMode;
  final List<ChatAttachment> attachments;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.linkedEntities = const [],
    this.researchMode = false,
    this.attachments = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {List<LinkedEntity> linkedEntities = const [],
      List<ChatAttachment> attachments = const []}) {
    // Server rows carry attachments under `attachments` (signed by the backend);
    // an explicit [attachments] arg (optimistic bytes) takes precedence.
    var atts = attachments;
    if (atts.isEmpty && json['attachments'] is List) {
      atts = (json['attachments'] as List)
          .whereType<Map>()
          .map((m) => ChatAttachment.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    return ChatMessage(
      id: json['id'] as String,
      text: (json['content'] ?? '') as String,
      isUser: json['sender_type'] == 'user',
      timestamp:
          (DateTime.tryParse((json['created_at'] ?? '') as String) ?? DateTime.now()).toLocal(),
      linkedEntities: linkedEntities,
      researchMode: json['research_mode'] == true,
      attachments: atts,
    );
  }
}

/// A write operation the assistant wants to perform, awaiting user permission.
class PendingAction {
  final String id;
  final String toolName;
  final String summary;
  final Map<String, dynamic> toolArgs;

  PendingAction({
    required this.id,
    required this.toolName,
    required this.summary,
    required this.toolArgs,
  });

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        id: json['id'] as String,
        toolName: (json['tool_name'] ?? '') as String,
        summary: (json['summary'] ?? 'The assistant wants to make a change.') as String,
        toolArgs: (json['tool_args'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
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
  // The assistant has paused awaiting permission for a write. The UI renders an
  // inline confirmation card while this is non-null.
  PendingAction? _pendingAction;
  bool _resolvingPending = false;
  // While a turn is in flight, poll the server as a safety net in case the
  // realtime push is missed (socket asleep, delivery dropped). Stops the instant
  // the turn resolves. Realtime stays the primary, instant path.
  Timer? _inFlightPoll;
  bool _resyncing = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  PendingAction? get pendingAction => _pendingAction;
  bool get resolvingPending => _resolvingPending;
  bool get isTyping => _isTyping;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get hasMore => _hasMore;
  String? get failedMessageId => _failedMessageId;
  String? get failedText => _failedText;
  String? get error => _error;
  String? get conversationId => _conversationId;

  Future<void> loadConversation(String conversationId,
      {String? accessToken}) async {
    // Re-entering the SAME conversation (e.g. popping back to the chat screen):
    // don't blow away the message list, but DO reconcile with the server. A turn
    // may have completed — or suspended for permission — while we were away and
    // realtime missed it (socket dropped / channel torn down). Resync recovers it.
    if (_conversationId == conversationId) {
      if (accessToken != null) {
        try {
          Supabase.instance.client.realtime.setAuth(accessToken);
        } catch (_) {}
      }
      // Re-subscribe if the channel was torn down, then pull the latest state.
      if (_channel == null) _subscribeRealtime(conversationId);
      await resync();
      return;
    }

    // Tear down old subscription + any in-flight poll for the previous convo
    _stopInFlightPoll();
    await _channel?.unsubscribe();
    _channel = null;

    _conversationId = conversationId;
    _messages.clear();
    _messageIds.clear();
    _nextBefore = null;
    _hasMore = true;
    _error = null;
    _pendingAction = null;
    notifyListeners();

    await _loadHistory(force: true);
    await _refreshPending();

    // Set realtime auth
    if (accessToken != null) {
      try {
        Supabase.instance.client.realtime.setAuth(accessToken);
      } catch (_) {}
    }

    _subscribeRealtime(conversationId);
  }

  /// Reconcile in-memory state with the server for the current conversation:
  /// pull the latest messages (merged by id) and any unresolved pending write,
  /// and clear a stale typing indicator. Safe to call on every screen re-entry.
  // Poll the server while a turn is in flight, in case realtime misses the push.
  void _startInFlightPoll() {
    _inFlightPoll?.cancel();
    _inFlightPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      // Stop once the turn has resolved (reply landed or a permission card showed).
      if (!_isTyping && !_resolvingPending) {
        _stopInFlightPoll();
        return;
      }
      resync();
    });
  }

  void _stopInFlightPoll() {
    _inFlightPoll?.cancel();
    _inFlightPoll = null;
  }

  // True if an in-flight optimistic user bubble with this exact text exists.
  bool _hasOptimisticFor(String content) =>
      _messages.any((m) => m.id.startsWith('optimistic_') && m.text == content);

  Future<void> resync() async {
    if (_conversationId == null || _resyncing) return;
    _resyncing = true;
    final convId = _conversationId!;

    try {
      final result = await ApiService.getMessages(convId, limit: 50);
      final msgs = result['data'] as List<Map<String, dynamic>>;
      for (final m in msgs) {
        final id = m['id'] as String;
        if (_messageIds.contains(id)) continue;
        // Skip the persisted echo of a user message we still hold as an optimistic
        // bubble (matched by content) — otherwise it shows twice until the in-flight
        // send swaps the bubble for the real record. Same guard the realtime path uses.
        if (m['sender_type'] == 'user' && _hasOptimisticFor((m['content'] ?? '') as String)) {
          continue;
        }
        _messageIds.add(id);
        final entities =
            _parseLinkedEntities(m['linked_entities']).map(LinkedEntity.fromJson).toList();
        _insertOrdered(ChatMessage.fromJson(m, linkedEntities: entities));
      }
    } catch (_) {
      // Network hiccup — keep what we have; pending refresh below still tries.
    }

    await _refreshPending();

    // Clear a stale typing dot only when the turn has actually resolved: either a
    // pending card is now showing, or the newest message is an assistant reply.
    // If neither, the turn may still be running server-side — leave the dot and
    // let realtime deliver the reply.
    final lastIsAssistant = _messages.isNotEmpty && !_messages.last.isUser;
    if (_isTyping && !_resolvingPending && (_pendingAction != null || lastIsAssistant)) {
      _isTyping = false;
    }
    // Turn resolved (or never was in flight) — no reason to keep polling.
    if (!_isTyping && !_resolvingPending) _stopInFlightPoll();
    _resyncing = false;
    notifyListeners();
  }

  // Fetch the latest unresolved pending write for the current conversation and
  // restore the confirmation card, unless we already hold one or are mid-resolve.
  // Notifies when the pending state changes so callers that don't notify
  // afterwards (e.g. loadConversation's full-load branch) still repaint the card.
  Future<void> _refreshPending() async {
    if (_conversationId == null || _resolvingPending) return;
    try {
      final pa = await ApiService.assistantPending(_conversationId!);
      final before = _pendingAction?.id;
      if (pa != null) {
        _pendingAction = PendingAction.fromJson(pa);
      } else if (_pendingAction != null) {
        // Server says nothing pending (resolved elsewhere) — drop a stale card.
        _pendingAction = null;
      }
      if (_pendingAction?.id != before) notifyListeners();
    } catch (_) {}
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
              if (_hasOptimisticFor(content)) {
                _messageIds.remove(id);
                return;
              }
            } else if (record['sender_type'] == 'assistant') {
              _isTyping = false;
              if (!_resolvingPending) _stopInFlightPoll();
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

  // Insert the optimistic user bubble (with any attachments) immediately, before
  // the message is uploaded/sent. Returns its id so the caller can hand it back
  // to [sendMessage] to reuse — this avoids a flash where the bare server-echoed
  // text message appears (and the image lingers in the composer) during upload.
  String beginOptimisticSend(
    String text, {
    bool researchMode = false,
    List<ChatAttachment> attachments = const [],
  }) {
    final optimisticId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    _messageIds.add(optimisticId);
    _insertOrdered(ChatMessage(
      id: optimisticId,
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      researchMode: researchMode,
      attachments: attachments,
    ));
    _isTyping = true;
    _error = null;
    _failedMessageId = null;
    _startInFlightPoll();
    notifyListeners();
    return optimisticId;
  }

  Future<Map<String, dynamic>?> sendMessage(
    String text, {
    bool researchMode = false,
    String? userMessageId,
    List<String>? attachmentIds,
    List<Map<String, dynamic>> mentions = const [],
    List<ChatAttachment> optimisticAttachments = const [],
    String? optimisticId,
  }) async {
    if (_conversationId == null || text.trim().isEmpty) return null;

    // Reuse a pre-inserted optimistic bubble if the caller already showed one
    // (attachment sends), otherwise insert it now (plain text sends).
    optimisticId ??= beginOptimisticSend(
      text,
      researchMode: researchMode,
      attachments: optimisticAttachments,
    );

    try {
      final resp = await ApiService.assistantRespond(
        conversationId: _conversationId!,
        text: text.trim(),
        researchMode: researchMode,
        userMessageId: userMessageId,
        attachmentIds: attachmentIds,
        mentions: mentions,
      );

      // Remove the optimistic message and replace with the real one from server
      _messages.removeWhere((m) => m.id == optimisticId);
      _messageIds.remove(optimisticId);

      // Carry the optimistic attachments (which hold local bytes) onto the
      // persisted user message so previews render instantly; a later history
      // reload swaps them for server-signed URLs.
      _upsertMessage(resp['user_message'] as Map<String, dynamic>?,
          attachments: optimisticAttachments);

      return _handleTurnResponse(resp);
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

  // Upsert a message row — if already added by realtime, replace to attach
  // linkedEntities; otherwise insert in timestamp order.
  void _upsertMessage(Map<String, dynamic>? msg,
      {List<LinkedEntity> linkedEntities = const [],
      List<ChatAttachment> attachments = const []}) {
    if (msg == null) return;
    final id = msg['id'] as String?;
    if (id == null) return;
    final newMsg = ChatMessage.fromJson(msg,
        linkedEntities: linkedEntities, attachments: attachments);
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      _messages[idx] = newMsg;
    } else {
      _messageIds.add(id);
      _insertOrdered(newMsg);
    }
  }

  // Process a /respond or /resume response: either the assistant paused for a
  // write permission, or it completed with an assistant message. Shared so both
  // sendMessage and resolvePending behave identically. Returns the conversation
  // map (may be null on resume responses).
  Map<String, dynamic>? _handleTurnResponse(Map<String, dynamic> resp) {
    if (resp['status'] == 'awaiting_permission') {
      final pa = resp['pending_action'] as Map<String, dynamic>?;
      if (pa != null) {
        _pendingAction = PendingAction.fromJson(pa);
        _isTyping = false;
        return resp['conversation'] as Map<String, dynamic>?;
      }
    }

    _pendingAction = null;
    final rawLinkedEntities = resp['linked_entities'] as List<dynamic>? ?? [];
    final parsedLinkedEntities = rawLinkedEntities
        .cast<Map<String, dynamic>>()
        .map(LinkedEntity.fromJson)
        .toList();
    _upsertMessage(resp['assistant_message'] as Map<String, dynamic>?,
        linkedEntities: parsedLinkedEntities);
    return resp['conversation'] as Map<String, dynamic>?;
  }

  /// Approve or deny the current pending write. On approve the backend executes
  /// the write and continues the agent (which may surface another pending action).
  Future<Map<String, dynamic>?> resolvePending({required bool approve}) async {
    final pa = _pendingAction;
    if (pa == null || _resolvingPending) return null;

    _resolvingPending = true;
    _error = null;
    // Clear the card and show the typing indicator while the agent continues.
    _pendingAction = null;
    _isTyping = true;
    _startInFlightPoll();
    notifyListeners();

    try {
      final resp = await ApiService.assistantResume(
        pendingActionId: pa.id,
        decision: approve ? 'approve' : 'deny',
      );
      return _handleTurnResponse(resp);
    } catch (_) {
      _error = 'Failed to ${approve ? 'approve' : 'deny'} the action. Please try again.';
      // Restore the card so the user can retry the decision.
      _pendingAction = pa;
      return null;
    } finally {
      _resolvingPending = false;
      _isTyping = false;
      notifyListeners();
    }
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
    _stopInFlightPoll();
    _channel?.unsubscribe();
    super.dispose();
  }

  void reset({bool loading = true}) {
    _stopInFlightPoll();
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
    _pendingAction = null;
    _resolvingPending = false;
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
