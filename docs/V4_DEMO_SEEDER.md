# V4 Demo Seeder

Deterministic backend accounts for visual gate screenshots, QA, and local demos.

## Script

`prime-backend/tools/seed_demo_scenarios.py`

## Safety

- Requires `ALLOW_DEMO_SEED=1`
- Refuses production-like database hosts
- Idempotent upsert by email — safe to re-run

## Usage

From `prime-backend/`:

```bash
ALLOW_DEMO_SEED=1 python3 tools/seed_demo_scenarios.py --yes
```

Reset and re-seed:

```bash
ALLOW_DEMO_SEED=1 python3 tools/seed_demo_scenarios.py --yes --reset
```

Password for all demo accounts: `DemoPrime123!`

## Accounts

| Email | Scenario | Use for |
|-------|----------|---------|
| `demo.empty@prime.local` | Brand-new user, no habit/team | Home new user, empty chats |
| `demo.matching@prime.local` | Waiting room, partial match, invited friend | Groups searching, notifications |
| `demo.filled@prime.local` | Day 22/30, full team, rich history | Primary gate account — home active, profile, conversation |

## Flutter gate alignment

| Gate golden | Suggested account |
|-------------|-------------------|
| `01_home_active` | `demo.filled@prime.local` |
| `02_groups_searching` | `demo.matching@prime.local` |
| `03_chats_filled` | `demo.filled@prime.local` |
| `04_conversation_filled` | `demo.filled@prime.local` |
| `05_profile_owner_filled` | `demo.filled@prime.local` |
| `06_home_new_user` | `demo.empty@prime.local` |
| `07_chats_empty` | `demo.empty@prime.local` |
| `08_notifications_empty` | `demo.empty@prime.local` |
| `09_groups_confirmation` | `demo.matching@prime.local` (matched, pending confirm) |

## Notes

- Metrics (streak, primes, team day) derive from seeded reports via `team_day` + `metrics_engine` — not hardcoded on `User` rows.
- Demo avatars are copied from `prime-flutter/assets/avatars/demo/` when present.
- After seeding, log in on a device/simulator with the account above to capture live screenshots that match gate compositions.
