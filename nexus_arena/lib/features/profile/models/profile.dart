class Profile {
  final String id;
  final String phone;
  final String displayName;
  final String? avatarUrl;
  final String kycStatus; // pending | submitted | approved | rejected
  final String? upiId;
  final String? gameUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.phone,
    required this.displayName,
    this.avatarUrl,
    required this.kycStatus,
    this.upiId,
    this.gameUid,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isKycApproved => kycStatus == 'approved';

  bool get canEditProfile =>
      DateTime.now().difference(updatedAt).inHours >= 24;

  DateTime get nextEditAllowedAt => updatedAt.add(const Duration(hours: 24));

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      upiId: json['upi_id'] as String?,
      gameUid: json['game_uid'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
