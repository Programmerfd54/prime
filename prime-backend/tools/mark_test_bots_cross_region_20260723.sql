UPDATE waiting_room_entries AS w
SET
    allow_other_regions = TRUE,
    expansion_offered_at = NOW()
FROM users AS u
WHERE
    w.user_id = u.id
    AND (
        u.email LIKE 'p23mskchapter%@example.com'
        OR u.email LIKE 'p23mobody%@example.com'
        OR u.email LIKE 'p23spbevening%@example.com'
    );

SELECT
    w.skill_id,
    w.region_code,
    w.allow_other_regions,
    COUNT(*) AS entries
FROM waiting_room_entries AS w
JOIN users AS u ON u.id = w.user_id
WHERE u.email LIKE 'p23%@example.com'
GROUP BY w.skill_id, w.region_code, w.allow_other_regions
ORDER BY w.skill_id, w.region_code, w.allow_other_regions;
