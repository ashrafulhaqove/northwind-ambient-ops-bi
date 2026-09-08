-- Q4: MDS leaderboard — CORRECTED
-- Bugs fixed:
--   1. Excluded INACTIVE specialists. Original had no status filter.
--      Petronella Emeka (INACTIVE) ranked #2 — would have received the award.
--      Achebe Noor (INACTIVE) near bottom — would have been placed on coaching plan.
--   2. Removed COALESCE(word_count, 0). NULL means transcript failed — not zero words.
--      Replacing NULL with 0 deflates averages for specialists who handled more failures.
--   3. Grouped by mds_id (stable key) not mds_name (free text, not guaranteed unique).
--   4. Fixed date boundary and excluded voided notes.

WITH deduped_notes AS (
    SELECT DISTINCT ON (note_id)
        note_id,
        mds_id,
        word_count,
        submitted_at_utc,
        is_void
    FROM note
    ORDER BY note_id, ingested_at_utc DESC
)
SELECT
    m.mds_id,
    m.mds_name,
    COUNT(*)                                                 AS notes_handled,
    ROUND(AVG(n.word_count)::numeric, 1)                     AS avg_word_count,
    ROUND(AVG(a.composite_score)::numeric, 4)                AS avg_composite,
    SUM(CASE WHEN n.word_count < 50 THEN 1 ELSE 0 END)       AS short_note_flags
FROM deduped_notes n
JOIN mds m          ON m.mds_id   = n.mds_id
LEFT JOIN note_audit a ON a.note_id = n.note_id
WHERE n.submitted_at_utc >= TIMESTAMP '2026-04-01'
  AND n.submitted_at_utc  < TIMESTAMP '2026-07-01'
  AND (n.is_void IS NULL OR n.is_void = false)
  AND m.status = 'ACTIVE'
GROUP BY m.mds_id, m.mds_name
ORDER BY avg_composite DESC NULLS LAST, notes_handled DESC;

-- Decision B was unsafe: two INACTIVE specialists appeared in the original leaderboard.
-- Corrected top performer: Marchetti, Ana (ACTIVE)
