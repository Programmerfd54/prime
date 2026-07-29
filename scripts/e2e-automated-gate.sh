#!/usr/bin/env bash
# Automated pre-release gate for manual E2E (see docs/prime-visual-redesign/11-E2E-QA-CHECKLIST.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== Backend pytest =="
(cd prime-backend && python3 -m pytest -q)

echo ""
echo "== Flutter analyze (errors only) =="
(cd prime-flutter && flutter analyze 2>&1 | rg "error •" && exit 1 || true)

echo ""
echo "== Flutter E2E automated coverage =="
(cd prime-flutter && flutter test \
  test/media_validation_test.dart \
  test/avatar_upload_test.dart \
  test/media_urls_test.dart \
  test/chat_composer_smoke_test.dart \
  test/app_avatar_test.dart \
  test/text_scale_smoke_test.dart \
  test/editorial_inventory_test.dart \
  test/pilot_golden_test.dart \
  test/home_state_test.dart \
  test/onboarding_preferences_test.dart \
  --reporter compact)

echo ""
echo "== Full Flutter suite =="
(cd prime-flutter && flutter test --reporter compact)

echo ""
echo "✅ Automated gate passed. Proceed with manual two-device checklist."
