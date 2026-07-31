# Team cycle V4 — implementation handoff

The implemented product loop is:

**today's action → visible team response → shared closed day → explained
personal result → deliberate next cycle.**

## User journey now represented in the product

1. A user can keep an active habit while searching for another team. The
   Groups section separates **Active** and **Search** only when both modes
   exist.
2. An early-start proposal is durable for 15 minutes. Other eligible users
   receive an in-app notification and APNs/FCM outbox event with confirm,
   continue-waiting and open-search actions. The in-app banner shows a live
   countdown and confirmation progress.
3. Introduction and agreement use optimistic actions, revisioned SSE and a
   disconnected-only polling fallback. Phase changes add system chat messages.
4. Changing team atomically deactivates the old membership with reason
   `manual_change`, starts the new queue and switches the client immediately;
   no page refresh or stale group refetch is required.
5. An active team opens on **Today**, with separate **Team** and **Progress**
   views. Today shows each member's report/check-in state and one primary
   action: report, support someone, or view the completed result.
6. `Нужна поддержка` and `Сегодня сложно` are realtime states. One-tap support
   creates an addressed team-chat event and notification, with a ten-minute
   anti-pressure cooldown.
7. Progress explains personal rhythm, shared days, support received/given and
   recovered hard days. Completed cycles expose four audited next steps:
   continue together, choose a new habit, increase difficulty or take a
   recovery week.

## Reliability contract

- Group and waiting-room state has a monotonic `revision`; clients discard
  stale events.
- Every membership deactivation has an immutable reasoned history event.
- `/groups/overview` returns active/preparing/search state in one read model.
- Group cards are assembled with five SQL statements for one or many groups.
- SSE is primary while connected; polling is a ten-second fallback only for
  preparation phases.
- Notification rows and push outbox entries are committed before provider
  delivery. Provider retries do not block the user action.
- Local mutations update Flutter state directly and avoid loading flashes.

## Release acceptance

- Backend regression: **116 passed**.
- Focused changed Flutter files: analyzer reports **no issues**.
- Focused Flutter product suite passed 29 checks before the final
  countdown/native-push hardening; the final repeat was blocked by the
  execution environment usage limit and remains a release command.
- PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` and authenticated p50/p95/p99 remain
  staging gates. SQLite timing is not used as a production performance claim.
- APNs delivery requires production key/team/bundle values. Android/web FCM
  delivery requires the platform Firebase project files. No real credentials
  are committed.

Run the release smoke path with three physical accounts:

`search → early-start push → three confirmations → agreement → first report →
support → closed day → completion choice`.
