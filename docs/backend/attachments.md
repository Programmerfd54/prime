# Attachments

Current upload routes are avatar, direct chat, group chat and report uploads.
The API currently reads each bounded upload into memory, validates the declared
MIME/extension allowlist, sends chat media to Matrix when enabled, and falls
back to local `uploads/media` storage otherwise. Images are capped at 10 MB,
documents at 25 MB, and general group media at 100 MB.

Known hardening work: inspect magic bytes rather than trusting only the client
MIME, strip EXIF, quarantine/process asynchronously, use private object storage
with signed download URLs, enforce per-user quotas, and delete old avatar files
after the database commit. These are not claimed as implemented by this change.
