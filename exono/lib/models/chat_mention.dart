/// A CRM record the user @-mentioned in the chat composer (Notion-AI-style).
///
/// In the message text a mention is encoded as a directive the backend can
/// re-parse and the bubble renderer can turn into an inline chip:
///
///   @[contact:<uuid>:Display Name]
///
/// The `mentions` array sent alongside the message (`{type, id}`) is what the
/// backend actually resolves; the directive in the text is for display + a
/// human-readable transcript.
class ChatMention {
  final String type; // contact | event | company
  final String id;
  final String displayName;

  const ChatMention({
    required this.type,
    required this.id,
    required this.displayName,
  });

  /// Matches a single directive: type, uuid, display name (no `]` in the name).
  static final RegExp directive =
      RegExp(r'@\[(contact|event|company):([0-9a-fA-F-]{36}):([^\]]+)\]');

  String toDirective() => '@[$type:$id:$displayName]';

  Map<String, dynamic> toRef() => {'type': type, 'id': id};

  /// Extract every mention from a message's text, in order of appearance.
  static List<ChatMention> parseAll(String text) {
    return directive.allMatches(text).map((m) {
      return ChatMention(
        type: m.group(1)!,
        id: m.group(2)!,
        displayName: m.group(3)!.trim(),
      );
    }).toList();
  }

  /// Replace every directive in [text] with its plain display name, e.g. for a
  /// notification preview or a copy-to-clipboard fallback.
  static String stripDirectives(String text) {
    return text.replaceAllMapped(directive, (m) => m.group(3)!.trim());
  }
}
