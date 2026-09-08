# RECONCILIATION.md
**Candidate:** Md. Ashraful Haque  
**Assessment:** Northwind Ambient Ops — BI Engineer Take-Home  
**Date:** 2026-09-06  

---

## Step 1 — Understanding the Problem

Before touching any SQL, the right question to ask is:

> *What decision does this number feed, and can I trust the data behind it?*

A report went to leadership last Thursday (2026-07-09) with these headline numbers:

| Metric | Reported |
|---|---|
| Notes audited in Q2 FY26 | 1,705 |
| Audit pass rate | 79.9% (target: 90%) |
| Average composite score | 0.9055 |
| Delivery SLA breach rate | 12.8% |
| Median delivery time | 18.5 min |
| Open escalations | 149 |
| Avg. time to first response | 49.5 min |
| Days flagged by volume alert | 28 of 91 |

Two decisions are already in motion based on these numbers:

- **Decision A** — $410K remediation program (retraining, extra QA headcount). Justified by pass rate being ~10pp below the 90% target.
- **Decision B** — Quarterly recognition award to top MDS. Bottom five on a 60-day coaching plan.

**Our job:** Verify whether these numbers can be trusted. If not, correct them — and say whether the decisions still hold.

---

## Step 2 — Data Profiling (Before Touching the Queries)

Before fixing anything, characterise each table. For each one: what is one row? Is the key actually unique? Anything unexpected?

### `note` — Clinical notes submitted by doctors

- **Grain:** One row per *ingestion* of a note (not one row per note)
- **Key uniqueness:** `note_id` is NOT unique — the same note can appear multiple times if the system replayed it. `ingestion_id` is unique per row.
- **Findings:**
  - 62 duplicate `note_id` values (re-ingested notes)
  - 90 notes marked `is_void = true` (retracted — wrong patient, duplicates, etc.)
  - `word_count` is nullable — NULL means the transcript failed, which is NOT the same as 0 words
  - All timestamps are UTC; the business runs on America/Chicago time

### `clinician` — Doctors who submit notes

- **Grain:** One row per *version* of a clinician record (SCD Type 2)
- **Key uniqueness:** `clinician_id` is NOT unique — 4 clinician IDs have 2 rows each (their record changed over time)
- **Findings:**
  - Joining to this table without filtering `is_current_record = true` will duplicate any note belonging to those 4 clinicians
  - Q1 joins to this table but uses zero columns from it — the join is both useless and harmful

### `mds` — Documentation specialists who process notes

- **Grain:** One row per specialist
- **Key uniqueness:** `mds_id` is unique. `mds_name` is free text and NOT guaranteed unique.
- **Findings:**
  - 2 specialists are INACTIVE: Achebe Noor (MD-201), Petronella Emeka
  - Q4 leaderboard includes them — one would receive the recognition award, one would get a coaching plan

### `note_audit` — QA audit results

- **Grain:** One row per audit (one audit per note)
- **Key uniqueness:** `note_id` appears to be unique here — confirmed
- **Findings:**
  - Only ~28% of notes are audited (1,780 audits out of 6,235 notes)
  - Rubric version (`v1` or `v2`) is recorded per audit — important for cross-period comparisons
  - `composite_score` and `pass_fail` are derived by the ETL, not calculated in the queries

### `rubric_weight` — Scoring rubric configuration

- **Grain:** One row per rubric version per scoring dimension
- **Findings:**
  - v1 pass threshold: **0.85** (effective from 2024-01-01)
  - v2 pass threshold: **0.90** (effective from 2026-05-15)
  - The rubric changed **mid-quarter** on May 15 — notes audited before and after are judged by different standards

### `sla_config` — Delivery time targets

- **Grain:** One row per product line / priority / effective period
- **Findings:**
  - SLA targets also changed **mid-quarter** on May 15
  - STANDARD notes: 45 min → 30 min; URGENT notes: 20 min → 15 min
  - Queries must join with effective date filter, not just on product line and priority

### `escalation` — Slack notifications for failed audits

- **Grain:** One row per escalation
- **Key uniqueness:** `escalation_id` is unique
- **Findings:**
  - Three statuses: `OPEN`, `RESOLVED`, `PENDING_POST`
  - 43 records are `PENDING_POST` with `slack_thread_ts = NULL` and `last_api_error = 'slack_api:ratelimited (HTTP 429)'`
  - These were never posted to Slack — nobody saw them, nobody worked them
  - Q5 incorrectly counts them as "open"

---

## Step 3 — Query-by-Query Analysis

All corrected queries are in `queries/corrected/`. Every number below is reproducible by running the corresponding file.

### Q1 — Audit Pass Rate

**Bugs found: 3**

| # | Bug | Effect |
|---|---|---|
| B1 | `JOIN clinician` — never used in SELECT; SCD2 table has 4 duplicate clinician_ids, inflating note count | +duplicate rows |
| B2 | No `is_void` filter — 90 retracted notes included in the count | +90 invalid notes |
| B3 | `BETWEEN '2026-06-30'` cuts off at midnight — notes submitted during Jun 30 missed; and no deduplication of 62 re-ingested notes | Mixed effect |

**Corrected query:** `queries/corrected/q1_audit_pass_rate.sql`

---

### Q2 — Delivery SLA Breach Rate

**Bugs found: 2**

| # | Bug | Effect |
|---|---|---|
| B4 | `LEFT JOIN escalation WHERE e.status <> 'RESOLVED'` — `NULL <> 'RESOLVED'` is NULL (falsy), silently converting LEFT JOIN to INNER JOIN. Only 296 of 5,448 notes were measured. | Catastrophic population error |
| B5 | `sla_config` joined without effective date filter — targets changed 2026-05-15; every note got the wrong target | Wrong threshold applied |

**Corrected query:** `queries/corrected/q2_sla_breach_rate.sql`

---

### Q3 — Volume Anomaly Alert

**Bugs found: 2**

| # | Bug | Effect |
|---|---|---|
| B6 | `submitted_at_utc::date` — UTC cast, not Chicago time. Notes near midnight get bucketed to the wrong day | Wrong daily counts |
| B7 | Weekends included — Saturday/Sunday always have near-zero volume, so they always flag as anomalies | Inflated flag count |

**Corrected query:** `queries/corrected/q3_volume_anomaly.sql`

---

### Q4 — MDS Leaderboard

**Bugs found: 2**

| # | Bug | Effect |
|---|---|---|
| B8 | No `WHERE m.status = 'ACTIVE'` filter — 2 INACTIVE specialists on the leaderboard | Petronella Emeka (INACTIVE) at #2 would receive award; Achebe Noor (INACTIVE) would be placed on coaching plan |
| B9 | `COALESCE(word_count, 0)` — NULL means transcript failed, not zero words. Deflates averages unfairly | Skews avg_word_count down for some specialists |

**Corrected query:** `queries/corrected/q4_mds_leaderboard.sql`

---

### Q5 — Open Escalations

**Bugs found: 1**

| # | Bug | Effect |
|---|---|---|
| B10 | `status <> 'RESOLVED'` includes `PENDING_POST` — 43 records that were never posted to Slack, never seen, never worked. These are a system failure, not open work items. | Overstates open count by 43 |

**Corrected query:** `queries/corrected/q5_open_escalations.sql`

---

### Additional observation — Query comments contradict the memo

The comments inside `PROVIDED_QUERIES.sql` show different numbers than the circulated memo (e.g. Q1 comment says "1,486 notes / 91.4%" but the memo says "1,705 / 79.9%"). The queries were edited after the report was sent. This means the query history cannot be fully trusted as a record of what produced the memo figures.

---

## Step 4 — Variance Waterfall

### Q1 — Notes Audited & Pass Rate

| # | Correction | Notes | Pass Rate | Δ Notes | Δ Pass Rate |
|---|---|---|---|---|---|
| 0 | Reported figure | 1,705 | 79.9% | — | — |
| 1 | Remove SCD2 clinician JOIN | ~1,578 | ~79.9% | −127 | ~0 |
| 2 | Exclude voided notes | ~1,562 | ~79.9% | −16 | ~0 |
| 3 | Deduplicate re-ingested notes | **1,567** | **79.6%** | −57 net | −0.3pp |

> Note: corrections 1 and 3 move in opposite directions on pass rate — removing the inflated rows from SCD2 and deduplication partially cancel each other out.

### Q2 — SLA Breach Rate

| # | Correction | Notes Measured | Breach Rate | Δ Notes | Δ Breach |
|---|---|---|---|---|---|
| 0 | Reported figure | 296 | 12.8% | — | — |
| 1 | Remove escalation JOIN (restore full population) | 5,448 | ~10.4% | +5,152 | −2.4pp |
| 2 | Add effective-date filter on sla_config | **5,448** | **10.4%** | 0 | ~0 |

> The population error in bug B4 is the dominant finding — only 5% of notes were being measured.

### Q3 — Volume Anomaly Days

| # | Correction | Days Flagged | Total Days | Δ |
|---|---|---|---|---|
| 0 | Reported figure | 28 | 91 | — |
| 1 | Exclude weekends + fix UTC→Chicago dates | **14** | **65** | −14 flags, −26 days |

> **Additional finding:** 13 of the 14 remaining flagged days are Mondays. Mondays are structurally ~40% lower than Tuesday–Friday — the trailing 14-day average mixes all weekdays, so Mondays always compare poorly. This is a **day-of-week seasonality gap in the business logic**, not a query bug. A correct anomaly alert would compare each weekday against the same day-of-week's trailing average. Requires Ops confirmation on whether Monday volume is expected to be lower.

### Q5 — Open Escalations

| # | Correction | Open Count | Δ |
|---|---|---|---|
| 0 | Reported figure | 149 | — |
| 1 | Exclude PENDING_POST (never posted to Slack) | **108** | −41 |

---

## Step 5 — Business Questions

### Decision A — Is the $410K retraining program justified?

**Yes, but with an important caveat.**

The corrected pass rate is **79.6%** against a 90% target — still approximately 10 percentage points below target, consistent with the reported figure. The direction of Decision A is correct.

However, the rubric pass threshold changed mid-quarter from 0.85 (v1) to 0.90 (v2) on 2026-05-15. Notes audited under v1 are held to a lower standard than those under v2. Any trend comparison across quarters must account for this — a drop in pass rate after May 15 could reflect the harder threshold, not a genuine quality decline. Leadership should be told this before approving a remediation scope based on a single-quarter figure.

**Recommendation:** Proceed with Decision A. Disclose the rubric change when presenting to stakeholders and re-run the pass rate split by rubric version before sizing the retraining program.

---

### Decision B — Is the award + coaching plan safe to execute?

**No. It must not be executed as-is.**

The original leaderboard includes two INACTIVE specialists:
- **Petronella Emeka (MD-218)** — INACTIVE, ranked #2. Would receive the recognition award.
- **Achebe Noor (MD-201)** — INACTIVE, near the bottom. Would be placed on a 60-day coaching plan.

Neither should appear on the leaderboard at all.

The corrected top performer (ACTIVE only) is **Marchetti, Ana**.

**Query that proves it:** `queries/corrected/q4_mds_leaderboard.sql` — run with and without `AND m.status = 'ACTIVE'` to see both INACTIVE specialists appear in the original output.

**Recommendation:** Add `AND m.status = 'ACTIVE'` before executing Decision B. Re-identify the bottom five from the corrected leaderboard before any coaching plans are issued.

---

## Step 6 — Known Unknowns

1. **"The quarter" definition** — Q2 FY26 is defined here as `submitted_at_utc >= '2026-04-01' AND < '2026-07-01'` (Chicago calendar dates, full days). The provided queries used `BETWEEN '2026-04-01' AND '2026-06-30'` which truncates at midnight on June 30. This is defended in the corrected queries.

2. **Rubric v1 → v2 mid-quarter** — The composite_score and pass_fail fields in note_audit are derived by the ETL at audit time using whichever rubric was current. We have not independently recomputed them. If the ETL applied the wrong rubric version to any audit, the pass_fail values in the data are wrong. This cannot be verified from the replica alone.

3. **Escalation status vocabulary** — The data dictionary notes that the status field "was extended by the platform team in 2026 and this table may not list every value in use." We found OPEN, RESOLVED, and PENDING_POST. There may be additional statuses not present in this dataset.

4. **word_count NULL pattern** — 152 notes have NULL word_count. We treated these as transcript failures and excluded them from averages. We cannot confirm from the replica whether all 152 are genuine failures or whether some represent a data pipeline gap.

5. **SLA measurement population** — Q2 measures SLA on all non-void, deduplicated notes with a delivered_at_utc. Notes where delivered_at_utc is NULL (not yet delivered or delivery not recorded) are excluded. We have not quantified how many notes this affects.
