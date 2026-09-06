# Northwind Ambient Ops — BI Engineer Assessment

**Candidate:** Md. Ashraful Haque  
**Role:** Business Intelligence Engineer, Global Operations  
**Submitted:** 2026-09-12

---

## What this is

A take-home assessment for Commure Bangladesh. The scenario: a Q2 FY26 operational report went to leadership with incorrect numbers, and two business decisions were made on the back of it. This repo contains the investigation, corrected queries, and the tooling built to prevent recurrence.

---

## Repo structure

```
├── README.md
├── RECONCILIATION.md         # Part 1 — bug findings, corrected numbers, business answers
├── DECISIONS.md              # Stakeholder conflict resolution for the Triage Workbench
├── UX_RATIONALE.md           # Part 2 — design decisions and interaction count
├── AI_USAGE.md               # Where AI was used and where I overrode it
├── SUBMISSION_CHECKLIST.md   # Filled checklist
│
├── queries/
│   ├── provided/             # Original buggy queries, untouched
│   └── corrected/            # Fixed queries, one file per question
│
├── schema.sql                # Original DDL (no PKs/FKs/indexes — intentional)
├── schema_additions.sql      # Audit trail table for Part 3 (designed by candidate)
│
├── data/                     # 7 synthetic CSVs (source data)
│
├── notebooks/
│   └── eda.ipynb             # Exploratory data analysis — profiling before fixing
│
├── src/                      # JavaScript modules used in Retool
│   └── *.js
│
├── tests/                    # Vitest unit tests
│   └── *.test.js
│
└── docs/
    └── adr/                  # Architecture Decision Records (≤3)
```

---

## How to reproduce any number in this repo

Every figure in `RECONCILIATION.md` comes from a query in `queries/corrected/`. To run:

```bash
# Using DuckDB (recommended)
duckdb < queries/corrected/q1_audit_pass_rate.sql

# Or load data into Postgres and run the .sql files directly
psql -f schema.sql
psql -c "\copy note FROM 'data/note.csv' CSV HEADER"
# ... repeat for all 7 tables
```

---

## What is wrong with this assessment?

*(≤150 words, as required)*

The assessment measures SQL debugging and Retool proficiency well, but underweights the skills that matter most in operational BI: understanding *why* data is shaped the way it is, not just fixing queries that operate on it. A BI engineer who can spot a LEFT JOIN bug but can't explain why the replica has no primary keys — or what that means for downstream trust — is only half-useful.

It also doesn't test stakeholder communication under ambiguity. The DECISIONS.md section hints at this, but a stronger signal would be a raw Slack thread or a conflicting verbal brief, not a clean written list of requirements.

Finally, the SCD2 clinician table and the mid-quarter rubric change are the most realistic parts of the dataset. More of that texture — and less of the obvious bugs — would better separate candidates.

---

## Live review prep

The 45-minute live session covers:
1. Walkthrough of the reconciliation waterfall
2. Keyboard-only operator loop in the Retool app
3. Q&A on any decision in this repo
4. Implementing a new requirement on the spot
