import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConversationModel {
  final String id;
  final String kind; // global | contact | event
  final String? title;
  final String? contactId;
  final String? eventId;
  final DateTime updatedAt;

  ConversationModel({
    required this.id,
    required this.kind,
    this.title,
    this.contactId,
    this.eventId,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'global',
      title: json['title'] as String?,
      contactId: json['contact_id'] as String?,
      eventId: json['event_id'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    switch (kind) {
      case 'global':
        return 'Global Assistant';
      case 'contact':
        return 'Contact Chat';
      case 'event':
        return 'Event Chat';
      default:
        return 'Chat';
    }
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

  Future<ConversationModel> getOrCreateGlobal() async {
    // Check if we already have a global one loaded
    final existing = _conversations.where((c) => c.kind == 'global').toList();
    if (existing.isNotEmpty) {
      _activeConversation = existing.first;
      notifyListeners();
      return existing.first;
    }

    final json = await ApiService.getOrCreateGlobalConversation();
    final convo = ConversationModel.fromJson(
        json['data'] as Map<String, dynamic>);
    _upsertConversation(convo);
    _activeConversation = convo;
    notifyListeners();
    return convo;
  }

  Future<ConversationModel> getOrCreateForContact(
      String contactId, String contactName) async {
    final existing =
        _conversations.where((c) => c.contactId == contactId).toList();
    if (existing.isNotEmpty) {
      _activeConversation = existing.first;
      notifyListeners();
      return existing.first;
    }

    final json = await ApiService.createConversation(
      kind: 'contact',
      contactId: contactId,
      title: contactName,
    );
    final convo = ConversationModel.fromJson(
        json['data'] as Map<String, dynamic>);
    _upsertConversation(convo);
    _activeConversation = convo;
    notifyListeners();
    return convo;
  }

  Future<ConversationModel> getOrCreateForEvent(
      String eventId, String eventName) async {
    final existing =
        _conversations.where((c) => c.eventId == eventId).toList();
    if (existing.isNotEmpty) {
      _activeConversation = existing.first;
      notifyListeners();
      return existing.first;
    }

    final json = await ApiService.createConversation(
      kind: 'event',
      eventId: eventId,
      title: eventName,
    );
    final convo = ConversationModel.fromJson(
        json['data'] as Map<String, dynamic>);
    _upsertConversation(convo);
    _activeConversation = convo;
    notifyListeners();
    return convo;
  }

  void setActive(ConversationModel convo) {
    _activeConversation = convo;
    notifyListeners();
  }

  void _upsertConversation(ConversationModel convo) {
    final idx = _conversations.indexWhere((c) => c.id == convo.id);
    if (idx >= 0) {
      _conversations[idx] = convo;
    } else {
      _conversations.insert(0, convo);
    }
  }

  void clear() {
    _conversations = [];
    _activeConversation = null;
    notifyListeners();
  }
}
