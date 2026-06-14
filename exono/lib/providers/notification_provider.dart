import 'package:flutter/foundation.dart';

/// A single pending notification that requires user action.
sealed class AppNotification {
  final String id;
  final DateTime createdAt;

  const AppNotification({required this.id, required this.createdAt});
}

/// Duplicate-contact notification produced during save when the server
/// detects an existing record that may match the new contact.
final class DedupNotification extends AppNotification {
  /// The existing contacts returned by checkDuplicateContacts.
  final List<Map<String, dynamic>> dupes;

  /// The form data the user entered (used to re-populate fields on merge/create).
  final Map<String, dynamic> pendingContact;

  /// The event the contact was being saved under, if any.
  final String? eventId;

  /// Raw notes / voice transcript, if any.
  final String? rawText;

  /// The source screen: 'capture' or 'manual'.
  final String source;

  const DedupNotification({
    required super.id,
    required super.createdAt,
    required this.dupes,
    required this.pendingContact,
    this.eventId,
    this.rawText,
    required this.source,
  });
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get count => _notifications.length;

  bool get hasNotifications => _notifications.isNotEmpty;

  void add(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void remove(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    notifyListeners();
  }
}
