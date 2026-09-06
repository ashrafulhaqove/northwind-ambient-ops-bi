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

*(To be completed)*

---

## Step 4 — Variance Waterfall

*(To be completed)*

---

## Step 5 — Business Questions

*(To be completed)*

---

## Step 6 — Known Unknowns

*(To be completed)*
