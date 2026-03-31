# Water Quality Monitor — Agent Context

## What This Project Is

An automated water quality monitoring pipeline for a municipal water utility (Riverside Municipal Water Authority, PWSID CA0000001, serving 15,000 people). The system runs 4 workflows at different cadences: hourly sensor ingestion, daily compliance analysis, on-demand violation remediation, and monthly regulatory reporting.

## Data Model — What's in Each File

| File | What It Contains | Who Reads It | Who Writes It |
|---|---|---|---|
| `config/system-info.yaml` | Utility name, PWSID, population served, regulatory contacts | regulatory-filer | Never modified by agents (manual config) |
| `config/epa-thresholds.yaml` | EPA MCLs, action levels, warning thresholds | compliance-checker, trend-analyst, remediation-planner | Never modified by agents |
| `config/monitoring-schedule.yaml` | Required sampling frequencies and counts | compliance-checker, regulatory-filer | Never modified by agents |
| `config/treatment-parameters.yaml` | Current treatment plant settings (doses, targets) | remediation-planner | Never modified by agents (operator-updated) |
| `data/readings/raw/` | Incoming sensor files (SCADA export, CSV/JSON) | data-ingestor | External (SCADA system or manual placement) |
| `data/readings/current.json` | All validated readings (rolling window) | trend-analyst, compliance-checker | data-ingestor |
| `data/readings/sensor-status.json` | Last-read timestamp and status per sensor | data-ingestor | data-ingestor |
| `data/readings/anomalies.json` | Rejected readings with rejection reasons | data-ingestor, trend-analyst | data-ingestor |
| `data/trend-analysis.json` | Latest trend analysis (moving averages, trends per parameter) | compliance-checker, remediation-planner | trend-analyst |
| `data/compliance-status.json` | Latest compliance determination with violations | remediation-planner, regulatory-filer | compliance-checker |
| `data/daily-stats.json` | Daily aggregated statistics (min/max/avg per parameter) | trend-analyst | calculate-daily-stats.sh |
| `data/monthly-aggregate.json` | Monthly aggregated statistics | compliance-checker | aggregate-monthly.sh |
| `data/monthly-summary.json` | Compiled monthly compliance summary | regulatory-filer | compliance-checker |
| `data/violations/active.json` | Current open violations with status | All agents | compliance-checker (create), remediation-planner (update), regulatory-filer (update) |
| `data/violations/corrective-action.json` | Active corrective action plan | remediation-planner, regulatory-filer | remediation-planner |
| `data/violations/resolved/` | Closed violations (archived JSON) | regulatory-filer | regulatory-filer |
| `data/history/` | Daily snapshots for 30-day trend baseline | trend-analyst | calculate-daily-stats.sh |
| `reports/daily/` | Daily compliance summary reports | Operator reference | regulatory-filer |
| `reports/monthly/` | Monthly compliance reports | Operator reference | regulatory-filer |
| `filings/` | Official regulatory filings (violation notices, monthly reports) | State agency | regulatory-filer |

## Domain Terminology

**MCL (Maximum Contaminant Level)** — The highest concentration of a contaminant allowed in drinking water, set by EPA under the Safe Drinking Water Act. Violating an MCL requires regulatory notification and corrective action.

**Action Level** — For lead and copper, EPA uses an action level rather than an MCL. If 10% of tap samples exceed the action level (15 μg/L for lead), treatment must be optimized. Measured as the 90th percentile of samples.

**PWSID** — Public Water System Identification number. Every public water system in the US has a unique PWSID (state abbreviation + 7-digit number). Required on all regulatory filings.

**Primacy Agency** — The state or tribal agency authorized by EPA to enforce the Safe Drinking Water Act. In most states this is the state environmental or health department. All violations are reported to the primacy agency first.

**Tier 1 Notification** — Required within 24 hours for violations posing an acute health risk (E. coli, nitrate >10 mg/L, certain chemical spills). Must include specific EPA-mandated language.

**Tier 2 Notification** — Required within 30 days for non-acute health-based violations.

**Tier 3 Notification** — Required within 1 year for monitoring/reporting violations.

**NTU (Nephelometric Turbidity Units)** — Measure of water clarity. High turbidity = particles in water = potential pathogen attachment points. EPA requires filtered systems to stay ≤1 NTU; any sample >5 NTU requires notification.

**CT Value** — Disinfection effectiveness measure: Concentration (mg/L) × Time (minutes). Must meet EPA minimum CT values for pathogen inactivation based on water temperature and pH.

**SCADA** — Supervisory Control and Data Acquisition. Industrial system for real-time monitoring and control of treatment plant and distribution sensors. This pipeline ingests SCADA exports.

## Workflow Entry Points

| Workflow | When to Run | Command |
|---|---|---|
| `ingest-sensor-data` | Hourly (auto via cron) | `ao workflow run ingest-sensor-data` |
| `daily-analysis` | Daily 6:30 AM (auto via cron) | `ao workflow run daily-analysis` |
| `remediation-workflow` | On violation detection | `ao workflow run remediation-workflow` |
| `monthly-regulatory-report` | 1st of month (auto via cron) | `ao workflow run monthly-regulatory-report` |

## Compliance Verdict Routing

The `check-compliance` phase routes based on verdict:
- **compliant** → `generate-daily-report` (standard daily summary)
- **warning** → `generate-daily-report` (includes warning flags and trend notes)
- **violation** → `generate-daily-report` (triggers violation notice generation)
- **critical** → `generate-daily-report` (includes Tier 1 public notification)

After the daily analysis completes, if violations are recorded in `data/violations/active.json`, the conductor queues a `remediation-workflow` task.

## Key Invariants Agents Must Respect

1. **Regulatory language is non-negotiable**: Public notifications for Tier 1 violations must include the required EPA language verbatim. Do not paraphrase or soften required language.

2. **Timestamps matter for compliance**: All regulatory filings must include accurate detection timestamps. The 24-hour notification deadline for Tier 1 violations is measured from the first confirmed detection, not when the workflow runs.

3. **90th percentile rule for lead/copper**: Lead and copper action levels are compared against the 90th percentile of first-draw samples, not the maximum. Do not flag a single high reading as an action level exceedance — context of the sample set is required.

4. **Never close a violation prematurely**: `track-corrective-action` should only return `resolved` when readings have returned to within MCLs for at least two consecutive monitoring periods. Single below-MCL reading is not sufficient for closure.

5. **Data quality before compliance**: Never run compliance analysis on unvalidated raw data. The `store-readings` phase must complete successfully before `check-compliance` can be meaningful.

## Script Assumptions

The bash scripts use Python3 for calculation logic:
- Python 3.8+ with standard library (no external packages required)
- Existing JSON data files in `data/` (scripts handle missing files gracefully with defaults)
- Working directory is the project root (cwd_mode: project_root in phases.yaml)
