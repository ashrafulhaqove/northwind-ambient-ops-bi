-- Q1: Audit pass rate — CORRECTED
-- Bugs fixed:
--   1. Removed useless JOIN to clinician (not used in SELECT; SCD2 rows inflated count by ~127)
--   2. Excluded voided notes (is_void = true)
--   3. Deduplicated re-ingested notes (keep latest ingestion per note_id)
--   4. Fixed date boundary: BETWEEN truncates Jun 30 at midnight; use < '2026-07-01' instead

WITH deduped_notes AS (
    SELECT DISTINCT ON (note_id)
        note_id,
        mds_id,
        submitted_at_utc,
        is_void
    FROM note
    ORDER BY note_id, ingested_at_utc DESC
)
SELECT
    COUNT(*)                                                            AS audited_notes,
    ROUND(100.0 * SUM(CASE WHEN a.pass_fail = 'PASS' THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                               AS pass_rate_pct,
    ROUND(AVG(a.composite_score)::numeric, 4)                          AS avg_composite
FROM deduped_notes n
JOIN note_audit a ON a.note_id = n.note_id
WHERE n.submitted_at_utc >= TIMESTAMP '2026-04-01'
  AND n.submitted_at_utc  < TIMESTAMP '2026-07-01'
  AND (n.is_void IS NULL OR n.is_void = false);

-- Reported: 1,705 notes | 79.9% pass rate
-- Corrected: 1,567 notes | 79.6% pass rate
