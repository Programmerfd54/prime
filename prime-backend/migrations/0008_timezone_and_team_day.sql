-- Team reporting day: user IANA timezone + fixed group reference timezone at cycle start.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS timezone VARCHAR(64);

ALTER TABLE groups
    ADD COLUMN IF NOT EXISTS reference_timezone VARCHAR(64);
