# Notifications

In-app notifications are durable rows in `notifications`; device registrations
are in `device_tokens`. `GET /notifications` keeps the existing `items` and
`unread_count` fields and now supports `limit` plus an opaque `before` cursor
ordered by `(created_at DESC, id DESC)`.

Every notification is committed together with a `push.notification` outbox
event. The background worker delivers it through:

- FCM HTTP v1 for `provider=fcm` tokens, with a short-lived OAuth token signed
  from a service account;
- APNs HTTP/2 token authentication for `provider=apns`.

Invalid provider tokens are removed; transient errors stay in the outbox with
bounded exponential retry. Device tokens and private keys are never logged.
`POST /devices/unregister` removes the current device at logout, preventing a
signed-out installation from receiving later team content.

The iOS Flutter target requests permission, obtains the APNs token and
registers it after authentication. Early-start pushes use the
`PRIME_EARLY_START` notification category with three actions: confirm, keep
waiting and open search. Foreground notifications remain visible.

Android uses the same Dart bridge (`prime/native_push`) with Firebase Cloud
Messaging when `prime-flutter/android/app/google-services.json` is present.
Gradle switches to the FCM source set automatically; without that file the app
builds in degraded mode (SSE + in-app notifications only). Setup steps live in
`prime-flutter/android/README_FCM.md`. Backend FCM credentials stay in env /
secret files — never commit service accounts or `google-services.json`.

SSE emits the same durable notification immediately while the app is open.
The current fan-out hub remains process-local, so multi-instance replay still
requires measured evidence before introducing cross-instance infrastructure.
