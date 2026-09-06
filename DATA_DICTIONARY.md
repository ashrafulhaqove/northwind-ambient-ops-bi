# Data Dictionary - Ambient Ops operational Replica
Maintained by Ops Analytics. Last reviewed 2026-02. Some sections are known to be behind the platform.

Global conventions

Every column suffixed _utc is TIMESTAMP without time zone, holding a UTC instant. The application writes UTC. Nothing in the database is localised.
Operational reporting, staffing, and every commitment we make to a client is stated in the America/Chicago business day. Reconciling those two facts is left to the reporting layer.
The replica ships with no primary keys, no foreign keys and no indexes. This is intentional on the platform side - it is a change-feed landing area, not a modelled warehouse.
Synthetic data. No real people.
## note - clinical documentation submissions
Grain: one row per ingestion of a note. A note is re-ingested when the upstream capture service replays it (transcription retry, client resubmit, backfill). Downstream consumers are expected to resolve to the version they want.

## clinician - clinician dimension
Grain: one row per clinician per version of their record (slowly-changing, type 2). Attributes such as region and employment status change over time; older versions are retained.

## mds - documentation specialist dimension
Grain: one row per specialist.

## note_audit - audit results
Grain: one row per audit. Roughly a quarter of notes are audited.


The seven sub-scores are the system of record. composite_score and pass_fail are conveniences computed from them and from rubric_weight.
## rubric_weight - scoring rubric, versioned
Grain: one row per rubric version per dimension.

## sla_config - delivery targets, effective-dated
Grain: one row per product line per priority per effective period. Targets change; history is retained so that past performance can be judged against the commitment that was actually in force at the time.

## escalation - Slack triage escalations
Grain: one row per escalation. Created by a service that writes the database row first, then posts to Slack, then records the thread reference on the row.



### Known gaps in this document
The status vocabulary above was extended by the platform team in 2026 and this table may not list every value in use.
No column-level nullability contract exists. Absence of a nullable note is not a guarantee.
Grain statements were written when the tables were created and have not been re-verified against production since. Verify them.
