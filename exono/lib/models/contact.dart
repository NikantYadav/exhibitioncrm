import 'dart:convert';

import '../db/app_database.dart';

class Contact {
  final String id;
  final String? userId;
  final String? companyId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? jobTitle;
  final String? linkedinUrl;
  final String? notes;
  final String? avatarUrl;
  final List<Map<String, dynamic>> contactAssets;
  final Map<String, dynamic>? scannedDetails;
  final String followUpStatus;
  final bool isPriority;
  final DateTime? lastContactedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Company? company;

  Contact({
    required this.id,
    this.userId,
    this.companyId,
    required this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.jobTitle,
    this.linkedinUrl,
    this.notes,
    this.avatarUrl,
    this.contactAssets = const [],
    this.scannedDetails,
    this.followUpStatus = 'not_contacted',
    this.isPriority = false,
    this.lastContactedAt,
    required this.createdAt,
    required this.updatedAt,
    this.company,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      userId: json['user_id'],
      companyId: json['company_id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'],
      email: json['email'],
      phone: json['phone'],
      jobTitle: json['job_title'],
      linkedinUrl: json['linkedin_url'],
      notes: json['notes'],
      avatarUrl: json['avatar_url'],
      contactAssets: (json['contact_assets'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? const [],
      scannedDetails: json['scanned_details'] != null
          ? Map<String, dynamic>.from(json['scanned_details'] as Map)
          : null,
      followUpStatus: json['follow_up_status'] ?? 'not_contacted',
      isPriority: json['is_priority'] ?? false,
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
      'user_id': userId,
      'company_id': companyId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'job_title': jobTitle,
      'linkedin_url': linkedinUrl,
      'notes': notes,
      'avatar_url': avatarUrl,
      'follow_up_status': followUpStatus,
      'is_priority': isPriority,
      'last_contacted_at': lastContactedAt?.toIso8601String(),
    };
  }

  String get fullName => '$firstName ${lastName ?? ''}'.trim();

  factory Contact.fromDrift(ContactsTableData row, {Company? company}) {
    return Contact(
      id: row.id,
      userId: row.userId,
      companyId: row.companyId,
      firstName: row.firstName,
      lastName: row.lastName,
      email: row.email,
      phone: row.phone,
      jobTitle: row.jobTitle,
      linkedinUrl: row.linkedinUrl,
      notes: row.notes,
      avatarUrl: row.avatarUrl,
      contactAssets: row.contactAssetsJson != null
          ? (jsonDecode(row.contactAssetsJson!) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : const [],
      scannedDetails: row.scannedDetailsJson != null
          ? Map<String, dynamic>.from(jsonDecode(row.scannedDetailsJson!) as Map)
          : null,
      followUpStatus: row.followUpStatus,
      isPriority: row.isPriority,
      lastContactedAt: row.lastContactedAt,
      createdAt: row.createdAt ?? row.updatedAt,
      updatedAt: row.updatedAt,
      company: company,
    );
  }
}

class Company {
  final String id;
  final String name;
  final String? website;
  final String? industry;
  final String? description;
  final String? location;
  final String? companySize;
  final String? productsServices;
  final String? headquarters;
  final String? employeeCount;
  final String? foundedYear;
  final String? linkedinUrl;
  final String? tickerSymbol;
  final DateTime? enrichedAt;
  final bool enrichmentFailed;
  final List<String> talkingPoints;

  Company({
    required this.id,
    required this.name,
    this.website,
    this.industry,
    this.description,
    this.location,
    this.companySize,
    this.productsServices,
    this.headquarters,
    this.employeeCount,
    this.foundedYear,
    this.linkedinUrl,
    this.tickerSymbol,
    this.enrichedAt,
    this.enrichmentFailed = false,
    this.talkingPoints = const [],
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'] ?? '',
      website: json['website'],
      industry: json['industry'],
      description: json['description'],
      location: json['location'],
      companySize: json['company_size'],
      productsServices: json['products_services'],
      headquarters: json['headquarters'],
      employeeCount: json['employee_count'],
      foundedYear: json['founded_year'],
      linkedinUrl: json['linkedin_url'],
      tickerSymbol: json['ticker_symbol'],
      enrichedAt: json['enriched_at'] != null ? DateTime.parse(json['enriched_at']) : null,
      enrichmentFailed: json['enrichment_failed'] ?? false,
      talkingPoints: (json['talking_points'] as List?)?.cast<String>() ?? const [],
    );
  }

  factory Company.fromDrift(CompaniesTableData row) {
    return Company(
      id: row.id,
      name: row.name,
      website: row.website,
      industry: row.industry,
      description: row.description,
      location: row.location,
      companySize: row.companySize,
      productsServices: row.productsServices,
      headquarters: row.headquarters,
      employeeCount: row.employeeCount,
      foundedYear: row.foundedYear,
      linkedinUrl: row.linkedinUrl,
      tickerSymbol: row.tickerSymbol,
      enrichedAt: row.enrichedAt,
      enrichmentFailed: row.enrichmentFailed,
      talkingPoints: row.talkingPointsJson != null
          ? (jsonDecode(row.talkingPointsJson!) as List).cast<String>()
          : const [],
    );
  }
}

