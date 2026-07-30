/// Result of `POST /auth/register`.
///
/// The account exists but cannot be used yet: the backend issues no token
/// until the code from the confirmation email is submitted.
class EmailVerificationTicket {
  const EmailVerificationTicket({
    required this.email,
    this.expiresAt,
    this.resendAvailableInSeconds = 0,
    this.devCode,
  });

  final String email;
  final DateTime? expiresAt;
  final int resendAvailableInSeconds;

  /// Present only when the backend runs with dev tools enabled, so local QA
  /// can finish signup without a mailbox.
  final String? devCode;

  factory EmailVerificationTicket.fromJson(Map<String, dynamic> j) {
    final expiresAt = j['expires_at'];
    return EmailVerificationTicket(
      email: (j['email'] as String? ?? '').toLowerCase(),
      expiresAt:
          expiresAt is String ? DateTime.tryParse(expiresAt)?.toLocal() : null,
      resendAvailableInSeconds: j['resend_available_in_seconds'] as int? ?? 0,
      devCode: j['verification_code'] as String?,
    );
  }
}
