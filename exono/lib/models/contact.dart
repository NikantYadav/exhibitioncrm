class Contact {
  final String id;
  final String? companyId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? jobTitle;
  final String? linkedinUrl;
  final String? bio;
  final String? notes;
  final String? avatarUrl;
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
    this.bio,
    this.notes,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.company,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      companyId: json['company_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phone: json['phone'],
      jobTitle: json['job_title'],
      linkedinUrl: json['linkedin_url'],
      bio: json['bio'],
      notes: json['notes'],
      avatarUrl: json['avatar_url'],
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
      'bio': bio,
      'notes': notes,
      'avatar_url': avatarUrl,
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

  Company({
    required this.id,
    required this.name,
    this.domain,
    this.website,
    this.industry,
    this.description,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'],
      domain: json['domain'],
      website: json['website'],
      industry: json['industry'],
      description: json['description'],
    );
  }
}
