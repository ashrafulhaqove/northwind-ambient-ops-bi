-- =====================================================================
--  Northwind Ambient Ops — "production" reporting queries
--  Owner: Ops Analytics (departed).  Last edited: 2026-07-02.
--  These are the exact queries behind the Q2 FY26 Ambient Ops Review.
--  Dialect: PostgreSQL 15.  All *_utc columns are TIMESTAMP (no tz), UTC.
--  DO NOT assume these are correct. Do not assume they are wrong either.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1  Audit pass rate  ->  reported as "1,486 notes audited, 91.4% pass"
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                                          AS audited_notes,
    ROUND(100.0 * SUM(CASE WHEN a.pass_fail = 'PASS' THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                              AS pass_rate_pct,
    ROUND(AVG(a.composite_score)::numeric, 4)                         AS avg_composite
FROM note n
JOIN note_audit a ON a.note_id = n.note_id
JOIN clinician  c ON c.clinician_id = n.clinician_id
WHERE n.submitted_at_utc BETWEEN TIMESTAMP '2026-04-01' AND TIMESTAMP '2026-06-30';


-- ---------------------------------------------------------------------
-- Q2  Delivery SLA breach rate  ->  reported as "4.2% breach, median 20 min"
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                                          AS notes_measured,
    ROUND(100.0 * SUM(CASE WHEN EXTRACT(EPOCH FROM (n.delivered_at_utc - n.submitted_at_utc))/60.0
                                > s.target_minutes THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                              AS breach_rate_pct,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (n.delivered_at_utc - n.submitted_at_utc))/60.0
    )                                                                 AS median_minutes
FROM note n
JOIN sla_config s
      ON s.product_line = n.product_line
     AND s.priority     = n.priority
LEFT JOIN escalation e
      ON e.note_id = n.note_id
WHERE n.submitted_at_utc BETWEEN TIMESTAMP '2026-04-01' AND TIMESTAMP '2026-06-30'
  AND e.status <> 'RESOLVED';


-- ---------------------------------------------------------------------
-- Q3  Daily volume + naive anomaly flag  ->  feeds the "volume alert" email
--     Business rule as written by Ops: flag any weekday more than 30% below
--     the trailing 14-day average.
-- ---------------------------------------------------------------------
WITH daily AS (
    SELECT
        n.submitted_at_utc::date              AS submit_day,
        COUNT(*)                              AS notes
    FROM note n
    WHERE n.submitted_at_utc::date BETWEEN DATE '2026-04-01' AND DATE '2026-06-30'
    GROUP BY 1
)
SELECT
    submit_day,
    notes,
    AVG(notes) OVER (ORDER BY submit_day ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING) AS trailing_avg,
    CASE WHEN notes < 0.70 * AVG(notes) OVER (ORDER BY submit_day
                                              ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING)
         THEN 'ANOMALY' END                                           AS flag
FROM daily
ORDER BY submit_day;


-- ---------------------------------------------------------------------
-- Q4  MDS leaderboard  ->  drives the monthly recognition award
-- ---------------------------------------------------------------------
SELECT
    m.mds_name,
    COUNT(*)                                              AS notes_handled,
    ROUND(AVG(COALESCE(n.word_count, 0))::numeric, 1)     AS avg_word_count,
    ROUND(AVG(a.composite_score)::numeric, 4)             AS avg_composite,
    SUM(CASE WHEN n.word_count < 50 THEN 1 ELSE 0 END)    AS short_note_flags
FROM note n
JOIN mds m         ON m.mds_id  = n.mds_id
LEFT JOIN note_audit a ON a.note_id = n.note_id
WHERE n.submitted_at_utc BETWEEN TIMESTAMP '2026-04-01' AND TIMESTAMP '2026-06-30'
GROUP BY m.mds_name
ORDER BY avg_composite DESC NULLS LAST, notes_handled DESC;


-- ---------------------------------------------------------------------
-- Q5  Escalation health  ->  reported as "open escalations" on the ops standup
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                                          AS open_escalations,
    ROUND(AVG(EXTRACT(EPOCH FROM (e.first_response_at_utc - e.created_at_utc))/60.0)::numeric, 1)
                                                                      AS avg_minutes_to_first_response,
    MIN(e.created_at_utc)                                             AS oldest_open
FROM escalation e
WHERE e.status <> 'RESOLVED'
  AND e.created_at_utc BETWEEN TIMESTAMP '2026-04-01' AND TIMESTAMP '2026-06-30';
