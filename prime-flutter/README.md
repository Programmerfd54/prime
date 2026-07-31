# PRIME — Flutter application

Мобильное приложение для трекера привычек ПРАЙМ.

## Stack

- Flutter (Dart)
- Dio (HTTP)
- Provider (state management)
- Material 3

## Конфигурация

Адрес backend указывается в `lib/config/constants.dart`:
```dart
const String kApiBaseUrl = 'http://10.0.2.2:8080'; // Android emulator → host
```
Для Chrome / десктопа используйте `http://localhost:8080`.
Для другого сервера передайте адрес при сборке:
```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

## Запуск

Платформенные папки (android/ios/web) не входят в репозиторий.
Сгенерируйте их один раз командой (существующий `pubspec.yaml` сохранится):

```bash
flutter create . --org com.prime --project-name prime
flutter pub get
flutter run
```

Перед запуском должен работать backend (`prime-backend`):
```bash
cd ../prime-backend
uvicorn app.main:app --reload --port 8080
```

### Android push (FCM)

Полная доставка push на Android включается файлом `android/app/google-services.json`
(скачать из Firebase Console). Без него приложение работает в degraded-режиме:
SSE + in-app уведомления. Подробнее: [android/README_FCM.md](android/README_FCM.md).

## Структура

```
lib/
  main.dart            — точка входа
  app.dart             — MaterialApp + тема
  config/              — константы и тема
  data/                — API клиент и хранилище токена
  models/              — DTO модели
  providers/           — провайдеры состояния (auth)
  screens/             — экраны приложения
  widgets/             — переиспользуемые виджеты
```

## Экраны

1. Онбординг (3 страницы)
2. Авторизация (email)
3. Создание профиля
4. Дашборд (статистика + календарь)
5. Группы (зал ожидания, приватные группы)
6. Навыки (каталог)
7. Профиль (достижения)
