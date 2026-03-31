# Water Quality Monitor

Automated water quality monitoring pipeline — hourly sensor ingestion, daily EPA compliance analysis, violation detection, corrective action planning, and monthly regulatory filings.

Built with [AO](https://github.com/launchapp-dev/ao) to demonstrate scheduled workflows, decision-based routing, and regulatory document generation.

## What It Does

1. **Hourly**: Ingests sensor readings (turbidity, chlorine, pH, temperature) from SCADA/data files, validates data quality, flags anomalies
2. **Daily**: Analyzes 24-hour trends against EPA MCLs (Maximum Contaminant Levels), issues compliance verdicts (compliant / warning / violation / critical), generates daily compliance reports
3. **On Violation**: Routes to a remediation workflow — assesses severity, generates corrective action plan, files required regulatory notices (Tier 1/2/3 public notification), tracks resolution until closure
4. **Monthly**: Aggregates all monitoring data, compiles required monthly compliance report for state primacy agency submission

## Agents

| Agent | Model | Role |
|---|---|---|
| **data-ingestor** | claude-haiku-4-5 | Parses sensor files, validates readings, flags anomalies |
| **trend-analyst** | claude-sonnet-4-6 | Analyzes parameter trends, detects threshold approaches |
| **compliance-checker** | claude-sonnet-4-6 | Evaluates readings against EPA MCLs, issues compliance verdicts |
| **remediation-planner** | claude-opus-4-6 | Root cause analysis, corrective action planning, resolution tracking |
| **regulatory-filer** | claude-sonnet-4-6 | Generates regulatory filings, violation notices, public notifications |

## Workflows

| Workflow | Schedule | Description |
|---|---|---|
| `ingest-sensor-data` | Hourly | Parse raw sensor files, validate, store structured readings |
| `daily-analysis` | Daily 6:30 AM | Trend analysis, compliance check, daily report |
| `remediation-workflow` | On violation | Assess, plan, file, track, close |
| `monthly-regulatory-report` | 1st of month | Aggregate monthly data, generate state filing |

## AO Features Demonstrated

- **Scheduled workflows** — hourly ingestion, daily analysis, monthly reporting
- **Command phases** — bash scripts for data parsing and aggregation
- **Decision contracts** — compliance verdicts (compliant/warning/violation/critical) routing to different handlers
- **Phase routing** — violations auto-route to remediation; critical violations escalate immediately
- **Multi-agent pipeline** — 5 specialized agents with different models and responsibilities
- **Output contracts** — structured JSON outputs with required fields validated between phases
- **Rework loops** — corrective action tracking retries until resolved (max 14 attempts)
- **Sequential-thinking MCP** — used for complex multi-parameter correlation analysis and root cause reasoning

## Quick Start

### Prerequisites

- [AO daemon](https://github.com/launchapp-dev/ao) installed and configured
- Node.js 18+ (for MCP servers)
- Python 3.8+ (for calculation scripts)

### Setup

```bash
# Clone this example
git clone https://github.com/launchapp-dev/ao-example-water-quality-monitor
cd ao-example-water-quality-monitor

# Copy env example (no API keys required for core functionality)
cp .env.example .env

# Make scripts executable
chmod +x scripts/*.sh

# Start the daemon in autonomous mode
ao daemon start --autonomous

# Watch live logs
ao daemon stream --pretty
```

### Trigger Workflows Manually

```bash
# Run sensor ingestion (normally runs hourly via cron)
ao workflow run ingest-sensor-data

# Run daily compliance analysis
ao workflow run daily-analysis

# Trigger remediation workflow (normally triggered on violation detection)
ao workflow run remediation-workflow

# Generate monthly regulatory report
ao workflow run monthly-regulatory-report
```

### Check Status

```bash
ao status
ao workflow list
ao errors list
```

## Data Model

```
data/
├── readings/
│   ├── raw/              # Incoming sensor files (SCADA export, CSV/JSON)
│   ├── processed/        # Raw files after ingestion
│   ├── current.json      # All validated readings (rolling)
│   ├── sensor-status.json  # Last-read timestamp per sensor
│   └── anomalies.json    # Rejected readings with rejection reason
├── trend-analysis.json   # Latest trend analysis output
├── compliance-status.json  # Latest compliance determination
├── daily-stats.json      # Daily aggregated statistics
├── monthly-aggregate.json  # Monthly aggregated statistics
├── monthly-summary.json  # Compiled monthly compliance summary
├── violations/
│   ├── active.json       # Current open violations
│   ├── corrective-action.json  # Active corrective action plan
│   └── resolved/         # Closed violations (archived)
└── history/              # Daily snapshots for trend analysis
```

## Regulatory Standards

The system enforces EPA National Primary and Secondary Drinking Water Regulations:

| Parameter | EPA Limit | Type |
|---|---|---|
| Nitrate | 10 mg/L as N | MCL (maximum) |
| E. coli | Zero presence | MCL (presence/absence) |
| Total Coliform | ≤5% of monthly samples | MCL (monthly %) |
| Turbidity (filtered) | ≤1 NTU | Treatment technique |
| Lead | 15 μg/L | Action level (90th %ile) |
| Copper | 1,300 μg/L | Action level (90th %ile) |
| Chlorine residual | ≥0.2 mg/L | Treatment technique |

## Adding Your Sensor Data

Place sensor data files in `data/readings/raw/` in one of these formats:

**JSON format:**
```json
{
  "source": "SCADA_system",
  "readings": [
    {
      "sensor_id": "TRB-TP-01",
      "location": "treatment_plant_effluent",
      "parameter": "turbidity",
      "value": 0.12,
      "unit": "NTU",
      "timestamp": "2026-03-30T06:00:00Z"
    }
  ]
}
```

The ingest-sensor-data workflow (runs hourly) will automatically pick up and process any new files.
