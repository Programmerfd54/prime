# PRIME: понятная карта проекта

Этот файл — шпаргалка для человека, который не обязан быть программистом.  
Цель: быстро понять, где что лежит, как всё связано, как запускать, проверять и безопасно менять приложение PRIME.

Актуально на 12.07.2026.

---

## 1. Из чего состоит проект

В рабочей папке `C:\dev` есть несколько важных директорий:

```text
C:\dev
  prime-flutter    мобильное приложение Flutter
  prime-backend    backend/API на FastAPI
  prime-landing    сайт/лендинг
  PRIME_DOCS       вспомогательные документы
```

Главные сейчас:

- `prime-flutter` — то, что пользователь видит на телефоне.
- `prime-backend` — серверная логика: регистрация, профиль, группы, чат, отчёты, Праймы.
- `prime-landing` — сайт, он отдельно от мобильного приложения.

---

## 2. Простая схема работы приложения

```text
Пользователь
  ↓
Flutter-приложение
  ↓ HTTPS
Backend API: https://api.inpr1me.ru/api/v1
  ↓
PostgreSQL база
  ↓
Matrix/Synapse для чатов
```

Если коротко:

1. Пользователь открывает Flutter-приложение.
2. Приложение отправляет запросы в backend.
3. Backend хранит пользователей, группы, отчёты, Праймы.
4. Для чатов backend связан с Matrix.

---

## 3. Главный пользовательский путь

Путь пользователя сейчас такой:

```text
Онбординг
  ↓
Регистрация / вход
  ↓
Заполнение профиля:
  имя, никнейм, область, возраст, текст о себе
  ↓
Выбор навыка
  ↓
Зал ожидания
  ↓
Группа из 6 человек
  ↓
Принятие участия и правил
  ↓
Чат группы
  ↓
Ежедневный отчёт
  ↓
Праймы, серия, прогресс
```

Важно:

- Имя может повторяться.
- Никнейм не может повторяться.
- Поиск пользователя делается по никнейму, не по UUID.
- Один человек может выбрать несколько навыков.
- В один и тот же навык человек не должен попасть дважды.
- Группа собирается по области.
- Через 1 час без полной группы можно предложить поиск из других областей.
- Готовый отчёт за день даёт `+1` Прайм.
- Новый пользователь стартует с `0` Праймов.
- Для создания пользовательской привычки нужно `10` Праймов.

---

## 4. Flutter: где что лежит

Папка:

```text
C:\dev\prime-flutter
```

Самые важные файлы:

```text
lib/main.dart
```

Точка входа в приложение. Тут решается, какой экран показать:

- загрузка;
- онбординг;
- вход/регистрация;
- заполнение профиля;
- главное приложение.

```text
lib/config/constants.dart
```

Адрес backend.  
Для сборки APK обычно передаётся:

```text
--dart-define=API_BASE_URL=https://api.inpr1me.ru
```

Внутри приложения к этому добавляется:

```text
/api/v1
```

```text
lib/config/theme.dart
```

Цвета, тема, шрифт, общий стиль PRIME.

```text
lib/data/api_client.dart
```

Главный HTTP-клиент.  
Если приложение “общается с сервером”, почти всегда это проходит через этот файл.

```text
lib/providers/auth_provider.dart
```

Состояние авторизации:

- есть ли токен;
- вошёл ли пользователь;
- заполнен ли профиль;
- кто текущий пользователь.

```text
lib/screens/
```

Экраны приложения.

Самые важные:

```text
auth_screen.dart           вход и регистрация
profile_setup_screen.dart  заполнение профиля
skills_screen.dart         навыки
groups_screen.dart         группы и зал ожидания
group_detail_screen.dart   детали группы, правила, отчёты
group_chat_screen.dart     чат группы
direct_chat_screen.dart    личные сообщения
dashboard_screen.dart      главная/статистика/друзья
profile_screen.dart        профиль
main_shell.dart            нижнее меню
```

```text
lib/models/
```

Модели данных: как Flutter понимает пользователя, группу, навык, отчёт.

Если backend добавил новое поле, часто нужно добавить его и в модель Flutter.

---

## 5. Backend: где что лежит

Папка:

```text
C:\dev\prime-backend
```

Самые важные файлы:

```text
app/main.py
```

Запускает FastAPI, подключает роутеры и `/api/v1`.

```text
app/config.py
```

Настройки через `.env`:

- база данных;
- JWT;
- Matrix;
- dev tools;
- задержка расширения поиска групп.

```text
app/models.py
```

Таблицы базы данных:

- `User`;
- `Group`;
- `GroupMember`;
- `WaitingRoomEntry`;
- `HabitReport`;
- `ReportAttachment`;
- `ChatMessage`;
- `FriendRequest`;
- `Friendship`;
- `DirectMessage`.

```text
app/schemas.py
```

Схемы запросов и ответов API.

```text
app/routers/auth.py
```

Регистрация и вход:

- `POST /auth/register` — создаёт неподтверждённый аккаунт и отправляет код на почту, токен не выдаёт;
- `POST /auth/verify-email` — принимает код и выдаёт первый токен;
- `POST /auth/resend-verification` — новый код (с задержкой между отправками);
- `POST /auth/login` — вернёт `403`, пока почта не подтверждена.

```text
app/routers/users.py
```

Профиль:

- `GET /users/me`;
- `PATCH /users/me`;
- avatar;
- смена пароля.

```text
app/routers/misc.py
```

Самый большой файл. Тут сейчас лежит много логики:

- список областей;
- список навыков;
- достижения;
- друзья;
- уведомления;
- подбор групп;
- зал ожидания;
- Matrix/chat;
- отчёты;
- начисление Праймов.

Позже этот файл лучше разделить на несколько маленьких роутеров, но для MVP он работает.

---

## 6. Главные backend endpoints

Базовый адрес:

```text
https://api.inpr1me.ru/api/v1
```

Регистрация и вход:

```text
POST /auth/register
POST /auth/verify-email
POST /auth/resend-verification
POST /auth/login
```

Профиль:

```text
GET   /users/me
PATCH /users/me
```

Области и навыки:

```text
GET /regions
GET /skills
```

Группы:

```text
POST   /groups/waiting-room
GET    /groups/waiting-room
GET    /groups/waiting-rooms
POST   /groups/waiting-room/expand
DELETE /groups/waiting-room
GET    /groups
GET    /groups/current
GET    /groups/{group_id}
POST   /groups/{group_id}/intro/continue
POST   /groups/{group_id}/rules/accept
```

Чат:

```text
GET  /chat/{group_id}/messages
POST /chat/{group_id}/messages
POST /chat/upload
POST /chat/sync
```

Отчёты:

```text
POST /reports
GET  /reports/calendar
POST /reports/upload
```

Друзья:

```text
GET  /users/by-nickname/{nickname}
POST /friends/requests
GET  /friends/requests
POST /friends/requests/{request_id}/respond
GET  /friends
```

---

## 7. Что уже важно знать про Праймы

Сейчас логика такая:

- новый пользователь имеет `0` Праймов;
- готовый отчёт за день даёт `+1` Прайм;
- повторная отправка готового отчёта в тот же день не даёт второй Прайм;
- если отчёт `not_ready`, Прайм не начисляется;
- при достижении `10` Праймов открывается право создавать пользовательские привычки;
- на экране навыков написано, что нужно `10` Праймов.

Где это в коде:

```text
Backend:
C:\dev\prime-backend\app\routers\misc.py

Flutter-текст:
C:\dev\prime-flutter\lib\screens\skills_screen.dart
```

---

## 8. Как запускать backend локально

Вариант через Docker:

```powershell
cd C:\dev\prime-backend
docker compose up -d --build
```

Проверка:

```powershell
Invoke-RestMethod http://localhost:8080/api/v1/health
```

Остановка:

```powershell
cd C:\dev\prime-backend
docker compose down
```

Логи:

```powershell
cd C:\dev\prime-backend
docker compose logs -f prime-api
```

---

## 9. Как запускать Flutter локально

Эмулятор Android должен быть включён.

Команда:

```powershell
cd C:\dev\prime-flutter
flutter run --dart-define=API_BASE_URL=https://api.inpr1me.ru
```

Если backend локальный на компьютере, для Android-эмулятора обычно используется:

```text
http://10.0.2.2:8080
```

Если backend на сервере:

```text
https://api.inpr1me.ru
```

---

## 10. Как собрать APK

Обычная сборка APK:

```powershell
cd C:\dev\prime-flutter
flutter build apk --release --dart-define=API_BASE_URL=https://api.inpr1me.ru
```

Готовый APK обычно появляется тут:

```text
C:\dev\prime-flutter\build\app\outputs\flutter-apk\app-release.apk
```

После сборки мы обычно копируем его в `C:\dev` с понятным именем, например:

```text
C:\dev\PRIME-beta-1.0.7-8-no-dev-short-skills.apk
```

---

## 11. Как проверять перед тем, как отдавать людям

Минимум перед тестовой раздачей:

### Backend

```powershell
cd C:\dev\prime-backend
.\.venv\Scripts\python.exe -m compileall app tests
.\.venv\Scripts\python.exe -m pytest
```

Ожидаем:

```text
passed
```

### Flutter

```powershell
cd C:\dev\prime-flutter
flutter analyze
flutter test
```

Ожидаем:

```text
No issues found
All tests passed
```

### Ручной smoke test

Проверить руками в приложении:

1. регистрация;
2. заполнение профиля;
3. выбор области;
4. выбор навыка;
5. попадание в зал ожидания;
6. сбор группы;
7. принятие участия;
8. принятие правил;
9. открытие чата;
10. отправка сообщения;
11. отправка отчёта;
12. начисление Прайма;
13. повторная отправка отчёта не должна начислить второй Прайм.

---

## 12. Как обновлять backend на сервере

Сервер:

```text
2.26.86.88
```

Backend:

```text
https://api.inpr1me.ru/api/v1
```

Папка на сервере:

```text
/opt/prime-api
```

Обычный порядок:

1. Локально проверить тесты.
2. Собрать архив backend.
3. Загрузить архив на сервер.
4. Сделать backup.
5. Распаковать.
6. Пересобрать контейнер.
7. Проверить `/health`.

Пример архива:

```powershell
cd C:\dev\prime-backend
tar -czf C:\dev\prime-backend-update.tar.gz app
```

Загрузка:

```powershell
scp C:\dev\prime-backend-update.tar.gz codexdeploy@2.26.86.88:/tmp/
```

Обновление на сервере:

```bash
ssh codexdeploy@2.26.86.88
cd /opt/prime-api
sudo tar -C /opt/prime-api -xzf /tmp/prime-backend-update.tar.gz
sudo docker compose up -d --build prime-api
```

Проверка:

```bash
curl http://127.0.0.1:8080/api/v1/health
```

Важно: перед серьёзными изменениями делать backup базы:

```bash
sudo docker exec prime-postgres pg_dump -U prime prime > /tmp/prime-backup.dump
```

---

## 13. Как понять, где искать баг

### “Нет соединения с сервером”

Смотреть:

```text
Flutter:
lib/config/constants.dart
lib/data/api_client.dart

Backend/server:
docker compose ps
docker compose logs prime-api
https://api.inpr1me.ru/api/v1/health
```

Частые причины:

- неправильный `API_BASE_URL`;
- backend не запущен;
- домен/DNS ещё не обновился;
- SSL/nginx не пропускает;
- телефон без интернета.

### “Не проходит регистрация”

Смотреть:

```text
Flutter:
auth_screen.dart
profile_setup_screen.dart

Backend:
app/routers/auth.py
app/routers/users.py
app/schemas.py
```

Частые причины:

- пароль меньше 8 символов;
- нет буквы или цифры;
- email уже занят;
- никнейм уже занят;
- профиль не заполнен полностью;
- область не выбрана.

### “Не выбирается область”

Смотреть:

```text
Flutter:
profile_setup_screen.dart
data/regions.dart
data/api_client.dart

Backend:
GET /regions
app/regions.py
app/routers/misc.py
```

### “Не собирается группа”

Смотреть:

```text
Backend:
app/models.py
app/routers/misc.py

Таблицы:
waiting_room_entries
groups
group_members
```

Главные функции:

```text
_maybe_match_waiting_room
_create_group
_activate_if_ready
waiting_room_payload
```

### “Чат не работает”

Смотреть:

```text
Flutter:
group_chat_screen.dart
direct_chat_screen.dart
data/api_client.dart

Backend:
app/matrix.py
app/routers/misc.py
docker compose logs matrix-synapse
```

Частые причины:

- Matrix не включён;
- неверный Matrix shared secret;
- room id не создан;
- пользователь не создан в Matrix;
- media URL не преобразуется.

### “Отчёт отправился, но Прайм не начислился”

Смотреть:

```text
Backend:
app/routers/misc.py
POST /reports
tests/test_reports.py
```

Правило:

- `status = ready` начисляет;
- `status = not_ready` не начисляет;
- второй `ready` за тот же день не начисляет повторно.

---

## 14. Что нельзя трогать без понимания

Лучше не удалять и не менять наугад:

```text
prime-backend/.env
prime-backend/docker-compose.yml
prime-backend/app/models.py
prime-backend/app/config.py
prime-flutter/android/
prime-flutter/pubspec.yaml
prime-flutter/lib/data/api_client.dart
```

Почему:

- `.env` содержит настройки сервера.
- `docker-compose.yml` запускает backend, PostgreSQL и Matrix.
- `models.py` — структура базы.
- `pubspec.yaml` — зависимости и версия приложения.
- `api_client.dart` — все запросы приложения.

Можно менять осторожно:

```text
screens/*.dart
widgets/*.dart
theme.dart
```

Но после изменений всё равно запускать:

```powershell
flutter analyze
flutter test
```

---

## 15. Как мы работаем без git

Так как сейчас друг объединяет версии из архивов, безопасный порядок такой:

1. Перед крупной правкой создать архив текущего состояния.
2. В имени архива писать дату и смысл.
3. После правки прогнать тесты.
4. Создать новый архив.
5. Написать краткую справку, что изменилось.

Пример имени:

```text
prime-project-2026-07-12-prime-awards.zip
```

Что обязательно положить в архив:

```text
prime-flutter/
prime-backend/
PRIME_GUIDE.md
```

Что обычно не нужно класть:

```text
build/
.dart_tool/
.venv/
__pycache__/
node_modules/
```

---

## 16. Как давать задачи Codex

Лучше писать не “сделай красиво”, а так:

```text
Нужно изменить экран навыков.
Файл примерно skills_screen.dart.
Сделай текст короче, добавь надпись про 10 Праймов.
После этого запусти flutter analyze и flutter test.
Если меняешь backend — запусти pytest.
В конце скажи, какие файлы изменил.
```

Для багов:

```text
Баг: при регистрации нельзя выбрать область.
Ожидаю: список областей открывается, область сохраняется в профиле.
Проверь Flutter и backend.
Сначала найди причину, потом исправь.
```

Для сервера:

```text
Нужно выложить backend на сервер.
Перед этим сделай backup.
После выкладки проверь /health и один live smoke test.
```

---

## 17. Словарь простыми словами

### Flutter

Мобильное приложение. То, что видит пользователь.

### Dart

Язык, на котором написан Flutter.

### Backend

Серверная часть. Она хранит данные и принимает решения.

### API

Набор адресов, куда приложение отправляет запросы.

### Endpoint

Один конкретный адрес API. Например:

```text
POST /reports
```

### Token

Ключ авторизации. После входа приложение хранит токен и отправляет его в backend.

### Model

Описание данных. Например пользователь, группа, отчёт.

### Provider

В Flutter это место, где хранится состояние. Например текущий пользователь.

### Screen

Экран приложения.

### Matrix

Отдельная система для чатов.

### PostgreSQL

База данных.

### Docker

Способ запускать backend, базу и Matrix в контейнерах.

### Smoke test

Быстрая ручная проверка, что главные функции живы.

---

## 18. Что ещё желательно сделать до полноценного MVP

Срочно/важно:

- пройти регистрацию с нуля на реальном APK;
- проверить выбор области;
- собрать хотя бы одну группу из 6 аккаунтов;
- проверить чат группы;
- проверить личные сообщения;
- проверить отчёт фото/видео/текст;
- проверить начисление Праймов;
- проверить, что повторный отчёт не начисляет Прайм второй раз;
- проверить русский текст на всех экранах;
- проверить APK на 2-3 разных Android-телефонах.

Средне важно:

- разделить большой backend-файл `misc.py` на отдельные роутеры;
- добавить больше backend-тестов;
- добавить больше Flutter widget-тестов;
- сделать нормальную админку/модерацию отчётов;
- улучшить загрузку медиа;
- добавить мониторинг ошибок.

Позже:

- CI/CD;
- миграции базы через Alembic;
- normal staging/prod окружения;
- Play Console / Firebase App Distribution;
- красивые push-уведомления.

---

## 19. Текущее состояние на 12.07.2026

По последней проверке:

```text
Backend tests: 14 passed
Flutter tests: 9 passed
Flutter analyze: No issues found
```

Строк кода:

```text
Всего:   10 832
Файлов:  63
Flutter: 7 613 строк
Backend: 3 219 строк
```

Последний известный APK:

```text
C:\dev\PRIME-beta-1.0.7-8-no-dev-short-skills.apk
```

Живой backend:

```text
https://api.inpr1me.ru/api/v1
```

---

## 20. Как учиться по этому проекту за 2 дня

### День 1: понять карту

1. Открыть `prime-flutter/lib/main.dart`.
2. Понять, как приложение выбирает первый экран.
3. Открыть `main_shell.dart`.
4. Понять нижнее меню.
5. Открыть `api_client.dart`.
6. Посмотреть, какие запросы Flutter отправляет на сервер.
7. Открыть `prime-backend/app/main.py`.
8. Понять, какие роутеры подключены.
9. Открыть `models.py`.
10. Понять основные таблицы.

### День 2: пройти один сценарий по коду

Сценарий “от выбора навыка до отчёта”:

```text
skills_screen.dart
  ↓
api_client.dart / joinWaitingRoom
  ↓
backend / POST /groups/waiting-room
  ↓
WaitingRoomEntry
  ↓
_maybe_match_waiting_room
  ↓
Group + GroupMember
  ↓
group_detail_screen.dart
  ↓
rules/accept
  ↓
group_chat_screen.dart
  ↓
POST /reports
  ↓
HabitReport + prime_points
```

Если понять этот путь — уже будет понятна половина проекта.

---

## 21. Актуальное состояние на 18.07.2026

Этот блок важнее старого раздела “Текущее состояние на 12.07.2026”: проект уже дорабатывался после той даты.

### Строки кода

Подсчёт сделан по двум главным папкам `C:\dev\prime-flutter` и `C:\dev\prime-backend`, без `build`, `.dart_tool`, `.venv`, кэшей, логов и загрузок.

```text
Всего:          13 252 строки
Файлов:            108
Flutter:         9 316 строк
Backend:         3 936 строк
```

Если считать только основной код приложения и backend (`prime-flutter/lib`, `prime-backend/app`, `prime-backend/tests`):

```text
Всего:          11 833 строки
Файлов:             58
Flutter lib:     8 462 строки
Backend app/tests: 3 371 строка
```

### Последняя собранная APK

```text
C:\dev\PRIME-beta-1.0.18-19-profile-stats.apk
```

Версия в `pubspec.yaml`:

```text
1.0.18+19
```

Важно: после этой APK в исходниках уже добавлен выбор навыка при отправке отчёта с главной. Чтобы тестеры увидели это изменение, нужно собрать новую APK.

### Главное правило по Праймам и успешным дням

Это сейчас принципиальная бизнес-логика:

- новый пользователь начинает с `0` Праймов;
- один готовый отчёт по навыку даёт `+1` Прайм;
- если у пользователя выбраны все 6 главных навыков, теоретически он может получить до `6` Праймов за день;
- успешный день считается не по количеству отчётов, а по факту активности в календарный день;
- 1 отчёт за день = 1 успешный день;
- 3 отчёта за день = всё равно 1 успешный день;
- 6 отчётов за день = всё равно 1 успешный день;
- отчёт `not_ready` Прайм не начисляет;
- редактирование/переделка уже готового отчёта не должна бесконечно начислять новые Праймы;
- для создания пользовательской привычки нужно накопить `10` Праймов;
- эти `10` Праймов не тратятся, это просто порог доступа.

### Что сейчас должно быть в приложении

- Название приложения на русском: `ПРАЙМ`.
- При входе пользователь попадает на главную вкладку.
- На главной должны показываться все активные челленджи.
- Если отчёт отправляется с главной, перед отправкой нужно выбрать навык.
- В календаре день оранжевый, если в этот день был хотя бы один отчёт по любому навыку.
- Серый индикатор нужен только для дней после регистрации/вступления в группу, где отчёта не было.
- День в календаре должен быть кликабельным, чтобы видеть, где отчёт был, а где нет.
- В группе участники должны отображаться с никами.
- При нажатии на участника открывается профиль со статистикой.
- В чужом профиле снизу фиксированная кнопка “Пригласить общаться”.
- Личные чаты 1 на 1 должны быть доступны с главной.
- В группе убраны “серия” и “лучшая серия”.

### Backend на сервере

Живой API:

```text
https://api.inpr1me.ru/api/v1
```

Проверка здоровья:

```bash
curl https://api.inpr1me.ru/api/v1/health
```

Сервер:

```text
2.26.86.88
```

Текущая машина подходит для MVP/беты, но не является запасом прочности под 10 000 активных пользователей с медиа и Matrix.

Последняя проверенная оценка сервера:

```text
CPU: 2 ядра
RAM: около 3.8 GiB
Swap: 4 GiB
Disk: около 59G всего, около 42G свободно
```

Вывод: для первых тестов и небольшой группы нормально. Для плана “до конца лета 10к пользователей” нужно заранее готовить:

- отдельный PostgreSQL или более мощный сервер;
- лимиты и сжатие медиа;
- регулярные backup базы и uploads;
- мониторинг CPU/RAM/Disk;
- понятный план восстановления;
- позже — второй сервер или managed-инфраструктуру.

### Web-версия

Flutter-проект можно собрать как web/PWA. Это полезно для iPhone и людей, которые не хотят ставить APK.

Рекомендуемый домен:

```text
https://app.inpr1me.ru
```

Сборка:

```powershell
cd C:\dev\prime-flutter
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://api.inpr1me.ru
```

На backend нужно будет разрешить CORS для домена web-приложения.

Что в web можно оставить:

- регистрация/вход;
- профиль;
- выбор области;
- выбор навыков;
- ожидание группы;
- группа;
- чат;
- текстовые отчёты;
- просмотр статистики;
- личные чаты.

Что может потребовать отдельной проверки:

- фото/видео с телефона через браузер;
- “кружки”;
- push-уведомления;
- сохранение сессии на iPhone;
- работа камеры в Safari.

### Что срочно перед раздачей следующей APK

1. Пересобрать APK после изменения “выбор навыка с главной”.
2. Быстро пройти smoke test:
   - новая регистрация;
   - выбор области;
   - выбор навыка;
   - сбор группы;
   - принятие правил;
   - вступительное сообщение в чат;
   - отправка отчёта из группы;
   - отправка отчёта с главной с выбором навыка;
   - начисление Праймов;
   - календарь: один активный день даже при нескольких отчётах;
   - открытие чужого профиля;
   - кнопка “Пригласить общаться”;
   - личный чат.
3. Проверить сервер:
   - `/health`;
   - свободное место;
   - что Docker-контейнеры подняты;
   - что Matrix живой.
4. Только после этого отдавать APK тестерам.

### Что ещё надо добавить в документацию позже

- точный порядок восстановления из backup;
- где лежит `.env` на сервере и какие переменные нельзя терять;
- схема таблиц базы;
- схема Matrix-комнат и связка с backend-группами;
- инструкция для друга: как сравнивать его frontend-архив с этой версией без git;
- чеклист релиза в конце июля.

### Обновление очередей от 18.07.2026

Новая логика формирования групп:

- сначала группа ищется только в области пользователя;
- если за 15 минут полная группа не собралась, приложение предлагает пользователю расширить поиск;
- расширение поиска не включается молча: пользователь должен согласиться на поиск по всей России;
- после согласия участник попадает в общий поиск по всем областям;
- если за 24 часа полная группа из 6 человек не собралась, backend может запустить группу от 3 человек;
- неполная группа стартует только если есть минимум 3 подходящих участника;
- разные области смешиваются только среди тех, кто согласился на поиск по всей России;
- если пользователь не соглашался на поиск по всей России, его не надо автоматически переносить в межрегиональную группу.

Backend-настройки по умолчанию:

```text
GROUP_REGION_EXPANSION_MINUTES=15
GROUP_PARTIAL_START_HOURS=24
GROUP_MIN_MEMBERS=3
```

Важно для выкладки: если на сервере в `.env` уже задан старый `GROUP_REGION_EXPANSION_MINUTES=60`, он перебьёт новый default. Для живого сервера нужно проверить `.env` и поставить `15`.
