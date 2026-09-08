-- Q3: Daily volume anomaly alert — CORRECTED
-- Bugs fixed:
--   1. UTC cast replaced with Chicago timezone conversion.
--      submitted_at_utc::date gives UTC calendar date, not the business day.
--      A note submitted at 11 PM Chicago time is 4 AM UTC next day — wrong bucket.
--   2. Weekends excluded. The alert is for weekday volume anomalies.
--      Saturday (DOW=6) and Sunday (DOW=0) always have near-zero volume,
--      so they always flag — producing false positives every weekend.
--   3. Fixed date boundary to use Chicago-local date
--
-- Remaining known issue (not a query bug — a business logic gap):
--   After fixing bugs 1 and 2, Mondays still flag almost every week (13 of 14 flags).
--   Mondays are structurally ~40% lower than Tue-Fri. The trailing 14-day average
--   mixes all weekdays, so Mondays always compare poorly. A proper anomaly alert
--   should compare each day against the same day-of-week trailing average.
--   This would require Ops to confirm whether Monday seasonality is expected behaviour.

WITH daily AS (
    SELECT
        (n.submitted_at_utc AT TIME ZONE 'America/Chicago')::date  AS submit_day,
        COUNT(*)                                                    AS notes
    FROM note n
    WHERE (n.submitted_at_utc AT TIME ZONE 'America/Chicago')::date
              BETWEEN DATE '2026-04-01' AND DATE '2026-06-30'
      AND EXTRACT(DOW FROM (n.submitted_at_utc AT TIME ZONE 'America/Chicago')) NOT IN (0, 6)
      AND (n.is_void IS NULL OR n.is_void = false)
    GROUP BY 1
)
SELECT
    submit_day,
    notes,
    ROUND(AVG(notes) OVER (
        ORDER BY submit_day ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING
    ), 1)                                                           AS trailing_avg,
    CASE WHEN notes < 0.70 * AVG(notes) OVER (
        ORDER BY submit_day ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING)
         THEN 'ANOMALY'
         ELSE 'NORMAL'
    END                                                             AS flag
FROM daily
ORDER BY submit_day;

-- Reported: 28 of 91 days flagged
-- Corrected: 14 of 65 weekdays flagged
-- Root cause: weekends (always near-zero) were included and UTC dates misbucketed notes
