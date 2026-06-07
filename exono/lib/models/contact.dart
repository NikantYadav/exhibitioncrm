class Contact {
  final String id;
  final String? companyId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? jobTitle;
  final String? linkedinUrl;
  final String? notes;
  final String? avatarUrl;
  final String enrichmentStatus;
  final String followUpStatus;
  final String followUpUrgency;
  final DateTime? lastContactedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Company? company;

  Contact({
    required this.id,
    this.companyId,
    required this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.jobTitle,
    this.linkedinUrl,
    this.notes,
    this.avatarUrl,
    this.enrichmentStatus = 'pending',
    this.followUpStatus = 'not_contacted',
    this.followUpUrgency = 'medium',
    this.lastContactedAt,
    required this.createdAt,
    required this.updatedAt,
    this.company,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      companyId: json['company_id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'],
      email: json['email'],
      phone: json['phone'],
      jobTitle: json['job_title'],
      linkedinUrl: json['linkedin_url'],
      notes: json['notes'],
      avatarUrl: json['avatar_url'],
      enrichmentStatus: json['enrichment_status'] ?? 'pending',
      followUpStatus: json['follow_up_status'] ?? 'not_contacted',
      followUpUrgency: json['follow_up_urgency'] ?? 'medium',
      lastContactedAt: json['last_contacted_at'] != null 
          ? DateTime.parse(json['last_contacted_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      company: json['company'] != null ? Company.fromJson(json['company']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'job_title': jobTitle,
      'linkedin_url': linkedinUrl,
      'notes': notes,
      'avatar_url': avatarUrl,
      'enrichment_status': enrichmentStatus,
      'follow_up_status': followUpStatus,
      'follow_up_urgency': followUpUrgency,
      'last_contacted_at': lastContactedAt?.toIso8601String(),
    };
  }

  String get fullName => '$firstName ${lastName ?? ''}'.trim();
}

class Company {
  final String id;
  final String name;
  final String? domain;
  final String? website;
  final String? industry;
  final String? description;
  final String? location;
  final String? region;
  final String? companySize;
  final String? productsServices;
  final bool isEnriched;

  Company({
    required this.id,
    required this.name,
    this.domain,
    this.website,
    this.industry,
    this.description,
    this.location,
    this.region,
    this.companySize,
    this.productsServices,
    this.isEnriched = false,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'] ?? '',
      domain: json['domain'],
      website: json['website'],
      industry: json['industry'],
      description: json['description'],
      location: json['location'],
      region: json['region'],
      companySize: json['company_size'],
      productsServices: json['products_services'],
      isEnriched: json['is_enriched'] ?? false,
    );
  }
}

