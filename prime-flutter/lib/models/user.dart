import '../core/features/moderator_features.dart';
import '../core/profile/privacy_settings.dart';

class UserModel {
  final String id;
  final String nickname;
  final String email;
  final String name;
  final String about;
  final String? photoUrl;
  final String? city;
  final String? regionCode;
  final String? regionName;
  final int? age;
  final bool profileCompleted;
  final int primePoints;
  final int successfulDays;
  final bool canCreateCustomSkills;
  final int streakShields;
  final bool shieldPending;
  final String? matrixUserId;
  final bool isModerator;
  final bool emailVerified;
  final bool marketingEmailsOptIn;
  final DateTime createdAt;
  final Map<String, bool> privacySettings;

  UserModel({
    required this.id,
    required this.nickname,
    required this.email,
    required this.name,
    required this.about,
    this.photoUrl,
    this.city,
    this.regionCode,
    this.regionName,
    this.age,
    required this.profileCompleted,
    required this.primePoints,
    required this.successfulDays,
    required this.canCreateCustomSkills,
    this.streakShields = 0,
    this.shieldPending = false,
    this.matrixUserId,
    required this.isModerator,
    this.emailVerified = true,
    this.marketingEmailsOptIn = true,
    required this.createdAt,
    Map<String, bool>? privacySettings,
  }) : privacySettings = privacySettings ?? Map.from(defaultPrivacySettings);

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        nickname: j['nickname'] as String? ?? '',
        email: j['email'] as String,
        name: j['name'] as String? ?? '',
        about: j['about'] as String? ?? '',
        photoUrl: j['photo_url'] as String?,
        city: j['city'] as String?,
        regionCode: j['region_code'] as String?,
        regionName: j['region_name'] as String?,
        age: j['age'] as int?,
        profileCompleted: j['profile_completed'] as bool? ?? false,
        primePoints: j['prime_points'] as int? ?? 0,
        successfulDays: j['successful_days'] as int? ?? 0,
        canCreateCustomSkills: j['can_create_custom_skills'] as bool? ?? false,
        streakShields: j['streak_shields'] as int? ?? 0,
        shieldPending: j['shield_pending'] as bool? ?? false,
        matrixUserId: j['matrix_user_id'] as String?,
        isModerator: ModeratorFeatures.enabled
            ? (j['is_moderator'] as bool? ?? false)
            : false,
        // Older API builds omit the flag; assume verified so they keep working.
        emailVerified: j['email_verified'] as bool? ?? true,
        marketingEmailsOptIn: j['marketing_emails_opt_in'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
        privacySettings: parsePrivacySettings(j['privacy_settings']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'email': email,
        'name': name,
        'about': about,
        'photo_url': photoUrl,
        'city': city,
        'region_code': regionCode,
        'region_name': regionName,
        'age': age,
        'profile_completed': profileCompleted,
        'prime_points': primePoints,
        'successful_days': successfulDays,
        'can_create_custom_skills': canCreateCustomSkills,
        'streak_shields': streakShields,
        'shield_pending': shieldPending,
        'matrix_user_id': matrixUserId,
        'is_moderator': isModerator,
        'email_verified': emailVerified,
        'marketing_emails_opt_in': marketingEmailsOptIn,
        'created_at': createdAt.toIso8601String(),
        'privacy_settings': privacySettings,
      };

  UserModel copyWith({String? about, bool? marketingEmailsOptIn}) => UserModel(
        id: id,
        nickname: nickname,
        email: email,
        name: name,
        about: about ?? this.about,
        photoUrl: photoUrl,
        city: city,
        regionCode: regionCode,
        regionName: regionName,
        age: age,
        profileCompleted: profileCompleted,
        primePoints: primePoints,
        successfulDays: successfulDays,
        canCreateCustomSkills: canCreateCustomSkills,
        streakShields: streakShields,
        shieldPending: shieldPending,
        matrixUserId: matrixUserId,
        isModerator: isModerator,
        emailVerified: emailVerified,
        marketingEmailsOptIn: marketingEmailsOptIn ?? this.marketingEmailsOptIn,
        createdAt: createdAt,
        privacySettings: privacySettings,
      );
}

class UserPublic {
  final String id;
  final String nickname;
  final String name;
  final String about;
  final String? photoUrl;
  final String? city;
  final String? regionCode;
  final String? regionName;
  final int? age;
  final int primePoints;
  final int successfulDays;
  final bool emailVerified;
  final Map<String, bool> privacySettings;

  UserPublic({
    required this.id,
    required this.nickname,
    required this.name,
    required this.about,
    this.photoUrl,
    this.city,
    this.regionCode,
    this.regionName,
    this.age,
    this.primePoints = 0,
    this.successfulDays = 0,
    this.emailVerified = true,
    Map<String, bool>? privacySettings,
  }) : privacySettings = privacySettings ?? Map.from(defaultPrivacySettings);

  factory UserPublic.fromJson(Map<String, dynamic> j) => UserPublic(
        id: j['id'] as String,
        nickname: j['nickname'] as String? ?? '',
        name: j['name'] as String? ?? '',
        about: j['about'] as String? ?? '',
        photoUrl: j['photo_url'] as String?,
        city: j['city'] as String?,
        regionCode: j['region_code'] as String?,
        regionName: j['region_name'] as String?,
        age: j['age'] as int?,
        primePoints: j['prime_points'] as int? ?? 0,
        successfulDays: j['successful_days'] as int? ?? 0,
        emailVerified: j['email_verified'] as bool? ?? true,
        privacySettings: parsePrivacySettings(j['privacy_settings']),
      );
}
