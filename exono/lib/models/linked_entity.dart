class LinkedEntity {
  final String type; // contact | event | email_draft
  final String id;
  final String displayName;
  final String? subtitle;

  LinkedEntity({
    required this.type,
    required this.id,
    required this.displayName,
    this.subtitle,
  });

  factory LinkedEntity.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    String displayName;
    String? subtitle;

    switch (type) {
      case 'contact':
        final first = (json['first_name'] as String?) ?? '';
        final last = (json['last_name'] as String?) ?? '';
        displayName = '$first $last'.trim();
        if (displayName.isEmpty) displayName = 'Contact';
        break;
      case 'event':
        displayName = (json['name'] as String?) ?? 'Event';
        final startDate = json['start_date'] as String?;
        subtitle = startDate != null ? _formatDate(startDate) : (json['location'] as String?);
        break;
      case 'email_draft':
        displayName = (json['subject'] as String?) ?? 'Email Draft';
        break;
      default:
        displayName = type;
    }

    return LinkedEntity(
      type: type,
      id: json['id'] as String,
      displayName: displayName,
      subtitle: subtitle,
    );
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
