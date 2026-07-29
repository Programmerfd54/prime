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

## Logs

Runtime logs are written to:

```text
logs/prime-api.log
```
