# PRIME Backend

FastAPI backend for PRIME development.

## Local Run

```bash
cp .env.example .env
docker compose up -d --build
```

API base URL:

```text
http://localhost:8080/api/v1
```

## Auth Rules

- Email is normalized to lowercase.
- Email must be valid.
- Password must be at least 8 characters.
- Password must contain at least one letter and one digit.
- `users.email` has a database unique constraint.

## Signup Email Confirmation

`POST /auth/register` creates the account with `users.email_verified_at = NULL`
and returns **no access token**. The session starts only after
`POST /auth/verify-email` accepts the 6-digit code that was emailed;
`POST /auth/login` answers `403` until then. `POST /auth/resend-verification`
issues a new code and invalidates the previous one.

Accounts that existed before this shipped are grandfathered as verified by the
migration in `app/db.py`, so nobody is locked out.

### Mail delivery

Set the `SMTP_*` and `MAIL_FROM` variables (see `.env.example`). For Yandex
use port **465** with `SMTP_USE_SSL=true` (recommended) or port **587** with
`SMTP_USE_STARTTLS=true`. Sending happens in a FastAPI background task, so an
SMTP outage does not fail registration — it only logs `email_send_failed`.

Test delivery without registering:

```bash
python3 tools/send_test_email.py your@gmail.com
```

Then check `logs/prime-api.log` for `email_sent` or `email_send_failed`.

Keep `EMAIL_VERIFICATION_EXPOSE_CODE=false` in all real environments.

### Yandex и антиспам

**Лучший вариант для продакшена:** почта на своём домене через
[Yandex 360](https://admin.yandex.ru) (`noreply@inpr1me.ru`), не личный
`@yandex.ru`. Личный ящик тоже работает для разработки, но чаще уходит в
«Спам» у Gmail и Mail.ru.

#### 1. Ящик и пароль приложения

1. В [Yandex ID](https://id.yandex.ru/security) включите **двухфакторную
   аутентификацию**.
2. Создайте **пароль приложения** → тип «Почта»:
   https://id.yandex.ru/security/app-passwords
3. В `.env` укажите полный логин и этот пароль (не основной пароль от аккаунта):

```env
SMTP_HOST=smtp.yandex.ru
SMTP_PORT=465
SMTP_USE_SSL=true
SMTP_USE_STARTTLS=false
SMTP_USERNAME=noreply@inpr1me.ru
SMTP_PASSWORD=<пароль-приложения>
MAIL_FROM=noreply@inpr1me.ru
MAIL_FROM_NAME=ПРАЙМ
MAIL_REPLY_TO=noreply@inpr1me.ru
EMAIL_VERIFICATION_EXPOSE_CODE=false
```

`MAIL_FROM` **должен совпадать** с `SMTP_USERNAME` (или быть подтверждённым
алиасом этого ящика в Yandex).

После правок `.env`:

```bash
docker compose up -d --build prime-api
```

#### 2. DNS записи (главное против «Спам»)

В панели регистратора домена `inpr1me.ru` (или где лежит DNS):

| Запись | Тип | Значение |
|--------|-----|----------|
| SPF | TXT `@` | `v=spf1 include:_spf.yandex.net ~all` |
| DKIM | TXT | из админки Yandex 360 → Почта → Домены → DKIM |
| DMARC | TXT `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc@inpr1me.ru` |

DKIM включается в Yandex 360 после подключения домена — сервис покажет имя
записи и значение; скопируйте их в DNS как есть.

Через 15–60 минут проверьте:

- https://www.mail-tester.com — отправьте туда письмо через `send_test_email.py`
- https://mxtoolbox.com/SuperTool.aspx — SPF/DKIM lookup для `inpr1me.ru`

Когда всё зелёное, DMARC можно ужесточить: `p=quarantine` или `p=reject`.

#### 3. Практика, которую уже делает API

- Письмо идёт и в **text**, и в **HTML** (не «картинка одна»).
- **Тема без кода** — код только в теле письма (код в теме = спам-фильтры).
- Отображаемое имя «ПРАЙМ», не «no-reply» без бренда.
- `Reply-To` на живой адрес поддержки.

#### 4. Если письмо всё равно в «Спам»

- Убедитесь, что DNS (SPF + DKIM + DMARC) прошли проверку.
- Отправьте себе 2–3 письма и нажмите «Не спам» в Gmail / Яндекс.Почте.
- Не шлите много писем подряд с одного IP при тестах (лимиты Yandex ~500/сутки
  на бесплатном тарифе).
- Для `@yandex.ru` → `@gmail.com` первое время «Спам» — нормально; для продакшена
  используйте `@inpr1me.ru` на Yandex 360.

## Logs

Runtime logs are written to:

```text
logs/prime-api.log
```
