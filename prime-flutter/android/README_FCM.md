# Android push (FCM)

PRIME registers device tokens through a native MethodChannel (`prime/native_push`).
Full FCM delivery is enabled automatically when Firebase is configured.

## Enable FCM

1. Create a Firebase project and add an **Android app** with package name `inpr1me.ru` (must match `applicationId` in `app/build.gradle.kts`).
2. Download `google-services.json` from the Firebase console.
3. Copy it to `android/app/google-services.json` (this path is gitignored).
4. Rebuild the app: `flutter run` or `flutter build apk`.

Gradle detects the file and:

- applies the Google Services plugin
- compiles the FCM source set (`src/fcm/kotlin`)
- links `firebase-messaging`

Without `google-services.json`, the app builds with the **degraded** path:
in-app notifications + SSE still work; the UI shows the push degraded banner.

## Backend pairing

Configure the API with FCM HTTP v1 credentials (see `prime-backend/.env.example`):

- `FCM_PROJECT_ID=prime-4078d`
- `FCM_SERVICE_ACCOUNT_FILE` or `FCM_SERVICE_ACCOUNT_JSON`

Device registration uses `POST /notifications/device-tokens` with `provider=fcm`.

## Manual E2E checklist

1. Install a build **with** `google-services.json` on a physical device or emulator with Google Play.
2. Log in — Settings → no degraded banner on Home/Groups.
3. Confirm token row in `device_tokens` for the user (`platform=android`, `provider=fcm`).
4. Trigger a team event (match, early start, mention) from another account.
5. Background the app → notification appears on channel **Команда PRIME**.
6. Tap notification → app opens to the correct group/search intent.
7. For early start pushes, action buttons **Подтвердить старт** / **Продолжить ждать** / **Открыть поиск** invoke the same Dart handlers as iOS.

## Notification channel

Backend messages use `android.notification.channel_id = prime_team`, created at runtime on first authorization.
