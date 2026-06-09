enum ContactAssetType { link, file }

class ContactAsset {
  final ContactAssetType type;
  final String title;
  final String url;

  const ContactAsset({
    required this.type,
    required this.title,
    required this.url,
  });

  factory ContactAsset.fromJson(Map<String, dynamic> j) => ContactAsset(
        type: j['type'] == 'file' ? ContactAssetType.file : ContactAssetType.link,
        title: j['title'] ?? '',
        url: j['url'] ?? '',
      );

  Map<String, dynamic> toJson() => {'type': type.name, 'title': title, 'url': url};
}
