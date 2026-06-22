import 'contact.dart';
import 'contact_asset.dart';
import 'event.dart';

class ContactTimelineItem {
  final String dateLabel;
  final String title;
  final String description;
  final bool isCurrent;
  final String? note;

  const ContactTimelineItem({
    required this.dateLabel,
    required this.title,
    required this.description,
    this.isCurrent = false,
    this.note,
  });
}

class ContactProfileData {
  final String id;
  final String? userId;
  final String initials;
  final String name;
  final String listName;
  final String title;
  final String company;
  final String companyId;
  final String listSubtitle;
  final String eventTag;
  final bool followUpDue;
  final String followUpStatus;
  final String productTag;
  final List<String> briefingItems;
  final String buyingAuthority;
  final String currentSentiment;
  final String primaryPainPoint;
  final String email;
  final String phone;
  final String linkedin;
  final String location;
  final String employeeRange;
  final String sector;
  final String website;
  final String avatarUrl;
  final List<String> sectors;
  final List<ContactAsset> assets;
  final String companyDescription;
  final String recentNews;
  final List<String> keyMarkets;
  final String decisionStructure;
  final List<String> aiInsights;
  final String strategicContext;
  final List<ContactTimelineItem> timelineItems;
  final List<Event> linkedEvents;
  final Map<String, dynamic>? scannedDetails;

  const ContactProfileData({
    required this.id,
    this.userId,
    required this.initials,
    required this.name,
    required this.listName,
    required this.title,
    required this.company,
    this.companyId = '',
    required this.listSubtitle,
    required this.eventTag,
    required this.followUpDue,
    this.followUpStatus = 'not_contacted',
    required this.productTag,
    required this.briefingItems,
    required this.buyingAuthority,
    required this.currentSentiment,
    required this.primaryPainPoint,
    required this.email,
    required this.phone,
    required this.linkedin,
    required this.location,
    required this.employeeRange,
    required this.sector,
    required this.website,
    this.avatarUrl = '',
    this.sectors = const [],
    this.assets = const [],
    required this.companyDescription,
    required this.recentNews,
    required this.keyMarkets,
    required this.decisionStructure,
    required this.aiInsights,
    required this.strategicContext,
    this.timelineItems = const [],
    this.linkedEvents = const [],
    this.scannedDetails,
  });

  ContactProfileData copyWith({
    String? id,
    String? userId,
    String? initials,
    String? name,
    String? listName,
    String? title,
    String? company,
    String? companyId,
    String? listSubtitle,
    String? eventTag,
    bool? followUpDue,
    String? followUpStatus,
    String? productTag,
    List<String>? briefingItems,
    String? buyingAuthority,
    String? currentSentiment,
    String? primaryPainPoint,
    String? email,
    String? phone,
    String? linkedin,
    String? location,
    String? employeeRange,
    String? sector,
    String? website,
    String? avatarUrl,
    List<String>? sectors,
    List<ContactAsset>? assets,
    String? companyDescription,
    String? recentNews,
    List<String>? keyMarkets,
    String? decisionStructure,
    List<String>? aiInsights,
    String? strategicContext,
    List<ContactTimelineItem>? timelineItems,
    List<Event>? linkedEvents,
    Map<String, dynamic>? scannedDetails,
  }) {
    return ContactProfileData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      initials: initials ?? this.initials,
      name: name ?? this.name,
      listName: listName ?? this.listName,
      title: title ?? this.title,
      company: company ?? this.company,
      companyId: companyId ?? this.companyId,
      listSubtitle: listSubtitle ?? this.listSubtitle,
      eventTag: eventTag ?? this.eventTag,
      followUpDue: followUpDue ?? this.followUpDue,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      productTag: productTag ?? this.productTag,
      briefingItems: briefingItems ?? this.briefingItems,
      buyingAuthority: buyingAuthority ?? this.buyingAuthority,
      currentSentiment: currentSentiment ?? this.currentSentiment,
      primaryPainPoint: primaryPainPoint ?? this.primaryPainPoint,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      linkedin: linkedin ?? this.linkedin,
      location: location ?? this.location,
      employeeRange: employeeRange ?? this.employeeRange,
      sector: sector ?? this.sector,
      website: website ?? this.website,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      sectors: sectors ?? this.sectors,
      assets: assets ?? this.assets,
      companyDescription: companyDescription ?? this.companyDescription,
      recentNews: recentNews ?? this.recentNews,
      keyMarkets: keyMarkets ?? this.keyMarkets,
      decisionStructure: decisionStructure ?? this.decisionStructure,
      aiInsights: aiInsights ?? this.aiInsights,
      strategicContext: strategicContext ?? this.strategicContext,
      timelineItems: timelineItems ?? this.timelineItems,
      linkedEvents: linkedEvents ?? this.linkedEvents,
      scannedDetails: scannedDetails ?? this.scannedDetails,
    );
  }
}

String cleanContactField(String? v) {
  if (v == null) return '';
  final t = v.trim();
  if (t.isEmpty || t.toLowerCase() == 'n/a' || t.toLowerCase() == 'na' || t == '-') return '';
  return t;
}

ContactProfileData mapContactToProfileData(Contact contact) {
  final c = cleanContactField;
  final initials = contact.firstName.isNotEmpty
      ? (contact.firstName[0] + (contact.lastName?.isNotEmpty == true ? contact.lastName![0] : ''))
      : '??';

  final companyName = contact.company?.name ?? '';
  final isIndependent = companyName.toUpperCase() == 'INDEPENDENT' || companyName.isEmpty;

  final assets = contact.contactAssets.map((j) => ContactAsset.fromJson(j)).toList();

  final companyDisplay = (isIndependent ? '' : companyName).toUpperCase();
  final title = c(contact.jobTitle);

  return ContactProfileData(
    id: contact.id,
    userId: contact.userId,
    initials: initials.toUpperCase(),
    name: contact.fullName.toUpperCase(),
    listName: contact.fullName,
    title: title,
    company: companyDisplay,
    companyId: isIndependent ? '' : (contact.companyId ?? ''),
    listSubtitle: title.isNotEmpty
        ? '$title${companyDisplay.isNotEmpty ? ' • $companyDisplay' : ''}'
        : companyDisplay,
    eventTag: '',
    followUpDue: contact.followUpStatus == 'urgent' || contact.followUpStatus == 'contacted',
    followUpStatus: contact.followUpStatus,
    productTag: isIndependent ? '' : c(contact.company?.productsServices),
    briefingItems: const [],
    buyingAuthority: '',
    currentSentiment: '',
    primaryPainPoint: '',
    email: c(contact.email),
    phone: c(contact.phone),
    linkedin: c(contact.linkedinUrl),
    location: isIndependent ? '' : c(contact.company?.location),
    employeeRange: isIndependent ? '' : c(contact.company?.companySize),
    sector: isIndependent ? '' : c(contact.company?.industry),
    website: isIndependent ? '' : c(contact.company?.website),
    avatarUrl: contact.avatarUrl ?? '',
    assets: assets,
    companyDescription: isIndependent ? '' : c(contact.company?.description),
    recentNews: '',
    keyMarkets: const [],
    decisionStructure: '',
    aiInsights: const [],
    strategicContext: '',
    timelineItems: const [],
    scannedDetails: contact.scannedDetails,
  );
}
