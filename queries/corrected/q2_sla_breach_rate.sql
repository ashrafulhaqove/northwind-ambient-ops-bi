-- Q2: Delivery SLA breach rate — CORRECTED
-- Bugs fixed:
--   1. Removed escalation JOIN entirely — it doesn't belong here.
--      Original: LEFT JOIN escalation WHERE e.status <> 'RESOLVED'
--      NULL <> 'RESOLVED' evaluates to NULL (falsy), silently converting the
--      LEFT JOIN to an INNER JOIN. Only 296 of 5,509 notes were measured.
--   2. Added effective date filter on sla_config — targets changed 2026-05-15.
--      Without this, all notes get the wrong (post-May-15) target applied uniformly.
--   3. Fixed date boundary: < '2026-07-01' instead of BETWEEN ... '2026-06-30'
--   4. Excluded voided notes

WITH deduped_notes AS (
    SELECT DISTINCT ON (note_id)
        note_id,
        product_line,
        priority,
        submitted_at_utc,
        delivered_at_utc,
        is_void
    FROM note
    ORDER BY note_id, ingested_at_utc DESC
)
SELECT
    COUNT(*)                                                            AS notes_measured,
    ROUND(100.0 * SUM(CASE
        WHEN EXTRACT(EPOCH FROM (n.delivered_at_utc - n.submitted_at_utc)) / 60.0
             > s.target_minutes THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                               AS breach_rate_pct,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (n.delivered_at_utc - n.submitted_at_utc)) / 60.0
    )::numeric, 1)                                                     AS median_minutes
FROM deduped_notes n
JOIN sla_config s
      ON  s.product_line   = n.product_line
      AND s.priority        = n.priority
      AND s.effective_from <= n.submitted_at_utc::date
      AND (s.effective_to IS NULL OR s.effective_to >= n.submitted_at_utc::date)
WHERE n.submitted_at_utc >= TIMESTAMP '2026-04-01'
  AND n.submitted_at_utc  < TIMESTAMP '2026-07-01'
  AND n.delivered_at_utc IS NOT NULL
  AND (n.is_void IS NULL OR n.is_void = false);

-- Reported: 12.8% breach over 296 notes | 18.5 min median
-- Corrected: 10.4% breach over 5,448 notes | 18.1 min median
