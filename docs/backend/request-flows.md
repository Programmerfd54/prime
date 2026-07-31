# Critical request flows

## Authentication and profile

Flutter `ApiClient` → `/auth/register|verify-email|login` → auth router →
`User` and verification-code tables → access JWT response. Authenticated
profile calls go through `get_current_user`, load `User`, and update
`last_seen_at` at most once per `LAST_SEEN_WRITE_INTERVAL_SECONDS`.

Profile updates call `/users/me` and write the user row. Avatar uploads call
`/users/me/avatar`, read the bounded upload into memory, write the current
local storage path, and persist `photo_url`. This path still needs a private
object-storage adapter and signature/EXIF processing before high-scale public
deployment.

## Matching and groups

Flutter waiting-room controller → `/groups/waiting-room` → validation and
queue upsert → bounded `FOR UPDATE SKIP LOCKED` candidate query → indexed
membership recheck → `groups`, `group_members`, queue deletion and in-app
notifications in the same database transaction. Group activation calls Matrix
before the current transaction commits; this remains a known external-I/O
coupling.

Home and Groups call one `/groups/overview` read model. Its group-card portion
loads memberships/users, today's reports, check-ins, group-day rows and cycle
starts in five queries independent of group count. Flutter no longer requests
one calendar per active habit. Group detail remains the source for heavier
weekly recap, milestones and personal impact.

Early start creates a durable 15-minute request and confirmation rows. The
initiator's transaction also creates notification/outbox records for the rest
of the queue. The third valid confirmation forms the group from current queue
members only. Manual group change deactivates membership, appends an audit
event, creates a new queue entry and returns that entry in one request.

## Check-in and reports

Flutter dashboard → `/groups/{id}/check-in` or `/reports` → membership check →
daily unique row (`group_check_ins` or `habit_reports`) → group-day/progress
calculation. The current check-in date uses server `date.today()` and does not
yet accept a client idempotency key or user timezone.

## Chat

Group history: `/chat/{group_id}/messages` → active membership →
`chat_messages` ordered by time. Sending creates a durable row after Matrix
send; group sends now accept `client_id`, use a deterministic Matrix transaction
ID, and return the existing row on retries. Direct messages already use
`direct_messages.client_id` and publish to the in-process hub after commit.

## Notifications and realtime

Notification producers insert `notifications` and `outbox_events` in one
transaction. The outbox worker delivers through FCM HTTP v1 or APNs HTTP/2 and
retries transient failures. Flutter reads `/notifications` with an opaque
`(created_at,id)` cursor. `/events/stream` publishes revisioned group/queue
state and live notification/chat events; reconnect replay and multi-instance
fanout remain follow-up work.
