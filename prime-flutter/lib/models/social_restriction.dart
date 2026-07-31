class SocialRestrictionStatus {
  const SocialRestrictionStatus({
    required this.active,
    this.scope,
    this.reasonCode,
    this.decisionId,
    this.expiresAt,
  });

  final bool active;
  final String? scope;
  final String? reasonCode;
  final String? decisionId;
  final DateTime? expiresAt;

  bool get isWriteBlocked {
    if (!active || expiresAt == null) return false;
    return expiresAt!.isAfter(DateTime.now());
  }

  factory SocialRestrictionStatus.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'];
    return SocialRestrictionStatus(
      active: json['active'] as bool? ?? false,
      scope: json['scope'] as String?,
      reasonCode: json['reason_code'] as String?,
      decisionId: json['decision_id'] as String?,
      expiresAt: expiresRaw is String ? DateTime.tryParse(expiresRaw) : null,
    );
  }
}
