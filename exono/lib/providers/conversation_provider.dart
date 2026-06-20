import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConversationModel {
  final String id;
  final String? title;
  final DateTime updatedAt;
  final String? firstMessagePreview;

  ConversationModel({
    required this.id,
    this.title,
    required this.updatedAt,
    this.firstMessagePreview,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      title: json['title'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      firstMessagePreview: json['first_message_preview'] as String?,
    );
  }

  /// Returns the best display title for this conversation.
  /// [firstMessageSnippet] overrides the stored preview (e.g. live from ChatProvider).
  String displayTitle({String? firstMessageSnippet}) {
    if (title != null && title!.isNotEmpty) return title!;
    final snippet = firstMessageSnippet ?? firstMessagePreview;
    if (snippet != null && snippet.isNotEmpty) {
      final clean = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
      return clean.length > 40 ? '${clean.substring(0, 40)}…' : clean;
    }
    return 'New Chat';
  }
}

class ConversationProvider extends ChangeNotifier {
  List<ConversationModel> _conversations = [];
  ConversationModel? _activeConversation;
  bool _isLoading = false;
  String? _error;

  List<ConversationModel> get conversations => _conversations;
  ConversationModel? get activeConversation => _activeConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await ApiService.listConversations();
      _conversations = list
          .map((j) => ConversationModel.fromJson(j))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ConversationModel> createGlobal() async {
    final json = await ApiService.createConversation();
    final convo = ConversationModel.fromJson(
        json['data'] as Map<String, dynamic>);
    upsertConversation(convo);
    _activeConversation = convo;
    notifyListeners();
    return convo;
  }

  Future<ConversationModel> getOrCreateGlobal() async {
    if (_activeConversation != null) {
      return _activeConversation!;
    }

    if (_conversations.isNotEmpty) {
      _activeConversation = _conversations.first;
      notifyListeners();
      return _conversations.first;
    }

    return createGlobal();
  }

  void setActive(ConversationModel? convo) {
    _activeConversation = convo;
    notifyListeners();
  }

  void upsertConversation(ConversationModel convo) {
    final idx = _conversations.indexWhere((c) => c.id == convo.id);
    if (idx >= 0) {
      _conversations[idx] = convo;
    } else {
      _conversations.insert(0, convo);
    }
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    try {
      // We need to implement this in ApiService first if not there
      // Assuming we added it to backend as requested
      await ApiService.deleteConversation(id);
      _conversations.removeWhere((c) => c.id == id);
      if (_activeConversation?.id == id) {
        _activeConversation = null;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clear() {
    _conversations = [];
    _activeConversation = null;
    notifyListeners();
  }
}
