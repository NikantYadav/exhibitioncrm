import 'dart:typed_data';

/// A file or image attached to a chat message.
///
/// Mirrors the assistant-ui attachment model (`type` image | document, plus
/// id / name / contentType). Two lifecycles share this type:
///  - Optimistic (just picked, not yet uploaded): [bytes] is set, [url]/[id] null.
///  - Persisted (from the server): [id] + [url] (a signed URL for images) are set.
class ChatAttachment {
  final String? id;
  final String name;
  final String? mimeType;
  final String kind; // image | file (assistant-ui: image | document)
  final String? url; // signed URL for persisted attachments (images)
  final Uint8List? bytes; // local bytes for an optimistic (pre-upload) attachment

  const ChatAttachment({
    this.id,
    required this.name,
    this.mimeType,
    required this.kind,
    this.url,
    this.bytes,
  });

  bool get isImage => kind == 'image';

  static const Set<String> _imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};

  /// Classify a local pick by mime/extension when no server `kind` is available.
  static String kindFor({String? mimeType, required String name}) {
    if (mimeType != null && mimeType.startsWith('image/')) return 'image';
    final dot = name.lastIndexOf('.');
    if (dot != -1) {
      final ext = name.substring(dot + 1).toLowerCase();
      if (_imageExts.contains(ext)) return 'image';
    }
    return 'file';
  }

  /// Build an optimistic attachment from a freshly picked file's bytes.
  factory ChatAttachment.local({required String name, required Uint8List bytes, String? mimeType}) {
    return ChatAttachment(
      name: name,
      bytes: bytes,
      mimeType: mimeType,
      kind: kindFor(mimeType: mimeType, name: name),
    );
  }

  /// Parse a server `message_attachments` row (as augmented by the backend with
  /// `kind`, `name`, and `signed_url`).
  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    final mime = json['mime_type'] as String?;
    final name = (json['name'] as String?) ??
        ((json['path'] as String?)?.split('/').last) ??
        'file';
    final kind = (json['kind'] as String?) ?? kindFor(mimeType: mime, name: name);
    return ChatAttachment(
      id: json['id'] as String?,
      name: name,
      mimeType: mime,
      kind: kind,
      url: json['signed_url'] as String?,
    );
  }
}
