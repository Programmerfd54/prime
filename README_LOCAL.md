# PRIME: локальный контур без продовой БД

Эта инструкция нужна, чтобы развернуть PRIME у себя на машине и тестировать изменения без подключения к боевому серверу и боевой базе данных.

Продовый контур использовать не нужно:

- не использовать `2.26.86.88`;
- не использовать `api.inpr1me.ru`;
- не копировать `.env` с сервера;
- не подключаться к продовой PostgreSQL;
- не использовать продовые Matrix/JWT/Postgres секреты.

Локальная схема должна быть такой:

```text
Flutter/Web локально → http://localhost:8080 → локальный backend → локальная PostgreSQL в Docker
```

## 1. Что должно быть установлено

- Docker Desktop
- Flutter SDK
- Python 3.12, если нужно запускать backend-тесты без Docker
- Git, если проект передаётся через репозиторий

## 2. Backend

Перейти в папку backend:

```powershell
cd prime-backend
```

Создать локальный `.env`:

```powershell
copy .env.local.example .env
```

Если файла `.env.local.example` нет, можно взять `.env.example`, но обязательно заменить значения на локальные и не вставлять продовые секреты.

Минимальный локальный `.env`:

```env
POSTGRES_DB=prime
POSTGRES_USER=prime
POSTGRES_PASSWORD=prime-local-password
DATABASE_URL=postgresql+asyncpg://prime:prime-local-password@prime-postgres:5432/prime

JWT_SECRET_KEY=local-dev-secret-change-me
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=43200
LOG_LEVEL=INFO

CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5000,http://localhost:8080,http://localhost:8081,http://127.0.0.1:8080,http://127.0.0.1:8081
API_DOCS_ENABLED=true
AUTH_LOGIN_RATE_LIMIT_ENABLED=false
ENABLE_DEV_TOOLS=false

GROUP_REGION_EXPANSION_MINUTES=15
GROUP_PARTIAL_START_HOURS=24
GROUP_MIN_MEMBERS=3

MATRIX_ENABLED=false
MATRIX_BASE_URL=http://matrix-synapse:8008
MATRIX_PUBLIC_BASE_URL=http://localhost:8008
MATRIX_SERVER_NAME=localhost
MATRIX_SHARED_SECRET=local-matrix-secret-change-me
```

Запустить локальный backend и локальную PostgreSQL:

```powershell
docker compose up -d --build prime-postgres prime-api
```

Проверить:

```powershell
curl http://localhost:8080/api/v1/health
```

Ожидаемый ответ:

```json
{"status":"ok"}
```

API:

```text
http://localhost:8080/api/v1
```

Документация API, если включён `API_DOCS_ENABLED=true`:

```text
http://localhost:8080/docs
```

## 3. Flutter Web

Перейти во Flutter:

```powershell
cd ..\prime-flutter
flutter pub get
```

Запустить web:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Важно: `API_BASE_URL` указывается без `/api/v1`.

Правильно:

```text
http://localhost:8080
```

Неправильно:

```text
http://localhost:8080/api/v1
```

Префикс `/api/v1` Flutter-клиент добавляет сам.

## 4. Android-эмулятор

Для Android-эмулятора адрес компьютера-хоста:

```text
http://10.0.2.2:8080
```

Запуск:

```powershell
flutter run -d emulator --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Debug APK:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## 5. Реальный Android-телефон в локальной сети

Если телефон подключён к той же Wi-Fi сети, нужно указать IP компьютера, где поднят backend.

Пример:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

Порт `8080` должен быть доступен с телефона.

## 6. Тесты backend

```powershell
cd prime-backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt -r requirements-dev.txt
pytest
```

## 7. Тесты Flutter

```powershell
cd prime-flutter
flutter test
flutter analyze
```

## 8. Сброс локальной базы

Осторожно: команда удаляет только локальную Docker-БД из этого проекта.

```powershell
cd prime-backend
docker compose down -v
docker compose up -d --build prime-postgres prime-api
```

## 9. Matrix

Для обычной локальной разработки можно оставить:

```env
MATRIX_ENABLED=false
```

Так проще тестировать регистрацию, профиль, навыки, очереди, группы, отчёты и базовый чат без внешнего Matrix-контура.

Если понадобится отдельно тестировать Matrix, нужно поднимать свой локальный Matrix/Synapse и использовать только локальные ключи/секреты.

## 10. Что проверить после запуска

1. `GET http://localhost:8080/api/v1/health` возвращает `{"status":"ok"}`.
2. `GET http://localhost:8080/api/v1/skills` возвращает 6 стартовых навыков.
3. Flutter Web открывается и не пишет `api/v1/api/v1`.
4. Регистрация создаёт пользователя в локальной базе.
5. Можно выбрать область, заполнить профиль и встать в очередь навыка.

