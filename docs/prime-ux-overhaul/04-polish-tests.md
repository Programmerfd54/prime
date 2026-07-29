# Stage 4 — Product polish & tests

**Status:** done  
**Depends on:** Stage 2 + Stage 3  
**Out of scope:** Firebase/Sentry production wiring, WebSocket backend

## Цель

Дожать удержание/ясность, a11y basics, аналитические воронки, тестовое покрытие и финальный [ACCEPTANCE.md](./ACCEPTANCE.md).

## 4.1 Product polish

- [x] Достижения: near-term first + empty CTA copy
- [x] Primes explainer на профиле
- [x] Tournaments: честный stub
- [x] Prep tip / matchmaking transparency (Stage 2)
- [x] Микрокопирайтинг терминов через `AppCopy`
- [~] Полный a11y audit (contrast/focus) — базовые Semantics на icon buttons есть

## 4.2 Analytics

- [x] Onboarding / auth / habits / search / team ready / messages
- [x] Facade без PII
- [~] Friends funnel events (частично через существующие screens)

## 4.3 Tests

### Есть

- [x] failure_mapper (+ Retry-After)
- [x] message_dedupe
- [x] api_client / api_base_url
- [x] models
- [x] app_states
- [x] async_error_view
- [x] about_quality
- [x] copy_terms

### Осознанно не делали (хрупкие / нужен mock-сервер)

- [ ] Full integration register→search без mock infra
- [ ] Two-client realtime e2e в CI

## 4.4 Финальная приёмка

См. [ACCEPTANCE.md](./ACCEPTANCE.md). Backend-blocked пункты помечены `[!]`.

## Команды

```bash
cd prime-backend && python3 -m pytest
cd prime-flutter && flutter analyze && flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```
