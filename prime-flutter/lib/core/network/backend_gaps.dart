/// Documented backend capabilities that the Flutter client does NOT fake.
///
/// Required for full product parity (not implemented server-side today):
/// - WebSocket / SSE channel for group + direct chat events
/// - Refresh tokens / token revoke / logout-all-devices
/// - Dedicated nickname availability endpoint (client uses by-nickname 404)
/// - Push notifications (FCM/APNs) registration + delivery — native iOS/Android
///   bridges register tokens; degraded Android fallback without Firebase config
/// - Per-message delivery / read receipts (inbox unread via last_read_at exists)
/// - Custom habit CRUD (flag `can_create_custom_skills` only)
/// - Real group voting (endpoint is currently a stub)
///
/// Implemented in this overhaul:
/// - Progressive profiling (about optional at setup; enforced at waiting-room join)
/// - X-Request-ID correlation headers
/// - DM inbox last message + unread (`GET /direct-chats`)
/// - Password reset (`/auth/forgot-password`, `/auth/reset-password`)
/// - Signup email confirmation (`/auth/verify-email`, `/auth/resend-verification`)
/// - Cancel outgoing friend request (`DELETE /friends/requests/{id}`)
abstract final class BackendGaps {
  static const realtimeTransport = 'websocket_or_sse';
  static const refreshTokens = 'auth_refresh';
  static const pushNotifications = 'fcm_apns';
}
