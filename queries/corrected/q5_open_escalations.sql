-- Q5: Open escalations — CORRECTED
-- Bugs fixed:
--   1. PENDING_POST excluded from "open" count.
--      Original: WHERE status <> 'RESOLVED' includes PENDING_POST.
--      PENDING_POST = never posted to Slack, never seen, never worked.
--      43 records in this state — all failed with HTTP 429 (rate limit), never retried.
--      These are a data quality / system failure issue, not open work items.
--   2. Fixed date boundary

-- Genuinely open escalations (posted to Slack, being worked)
SELECT
    COUNT(*)                                                              AS open_escalations,
    ROUND(AVG(EXTRACT(EPOCH FROM (e.first_response_at_utc - e.created_at_utc)) / 60.0)::numeric, 1)
                                                                          AS avg_minutes_to_first_response,
    MIN(e.created_at_utc)                                                 AS oldest_open
FROM escalation e
WHERE e.status = 'OPEN'
  AND e.created_at_utc >= TIMESTAMP '2026-04-01'
  AND e.created_at_utc  < TIMESTAMP '2026-07-01';

-- Stranded escalations (system failure — never posted to Slack)
SELECT
    COUNT(*)            AS stranded_count,
    MIN(created_at_utc) AS earliest,
    MAX(created_at_utc) AS latest,
    DISTINCT last_api_error AS failure_reason
FROM escalation
WHERE status = 'PENDING_POST'
  AND slack_thread_ts IS NULL;

-- Reported: 149 open (mixed OPEN + PENDING_POST)
-- Corrected: 108 genuinely open | 43 stranded (system failure, separate issue)
