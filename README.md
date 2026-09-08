# Northwind Ambient Ops — BI Engineer Assessment

**Candidate:** Md. Ashraful Haque  
**Role:** Business Intelligence Engineer, Global Operations  
**Submitted:** Partial submission — see withdrawal note

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

The assessment is well-constructed and tests a meaningful range of BI skills. If I were to suggest one area to expand: it could go deeper on data trust and lineage — not just finding query bugs, but also asking candidates to reason about where data comes from, how it gets there, and what assumptions might quietly break in production. The SCD2 clinician table and the mid-quarter rubric and SLA changes are the most realistic parts of the dataset and I found them the most interesting to work through. More problems of that shape — where the data itself requires careful interpretation — would be a great addition. The stakeholder conflict exercise is also valuable; a verbal or unstructured version of it might surface how candidates communicate under ambiguity, which is hard to test in writing.

---

