#!/usr/bin/env bash
# calculate-daily-stats.sh — Compute daily statistics from current readings
# Outputs summary stats to data/daily-stats.json

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READINGS_FILE="$PROJECT_ROOT/data/readings/current.json"
OUTPUT_FILE="$PROJECT_ROOT/data/daily-stats.json"
DATE=$(date +%Y-%m-%d)

mkdir -p "$PROJECT_ROOT/data"

if [ ! -f "$READINGS_FILE" ]; then
  echo "No readings file found — creating empty stats"
  cat > "$OUTPUT_FILE" << EOF
{
  "date": "$DATE",
  "status": "no_data",
  "message": "No readings available yet. Run sensor ingestion first.",
  "parameters": {}
}
EOF
  exit 0
fi

# Use Python3 for stats calculation
python3 << PYEOF
import json
import sys
from datetime import datetime, timezone, timedelta

date_str = "$DATE"
readings_path = "$READINGS_FILE"
output_path = "$OUTPUT_FILE"

with open(readings_path) as f:
    data = json.load(f)

readings = data.get("readings", [])

# Group by parameter
by_param = {}
for r in readings:
    param = r.get("parameter")
    value = r.get("value")
    if param and value is not None:
        if param not in by_param:
            by_param[param] = []
        by_param[param].append(float(value))

# Calculate stats per parameter
stats = {}
for param, values in by_param.items():
    if values:
        stats[param] = {
            "count": len(values),
            "min": round(min(values), 4),
            "max": round(max(values), 4),
            "avg": round(sum(values) / len(values), 4),
            "p90": round(sorted(values)[int(len(values) * 0.9)], 4) if len(values) >= 10 else None
        }

output = {
    "date": date_str,
    "status": "calculated",
    "total_readings": len(readings),
    "parameters": stats,
    "calculated_at": datetime.now(timezone.utc).isoformat()
}

with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"Daily stats calculated: {len(stats)} parameters, {len(readings)} total readings")
PYEOF
