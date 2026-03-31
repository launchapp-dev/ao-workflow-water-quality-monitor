#!/usr/bin/env bash
# aggregate-monthly.sh — Aggregate all daily readings for the current month

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HISTORY_DIR="$PROJECT_ROOT/data/history"
OUTPUT_FILE="$PROJECT_ROOT/data/monthly-aggregate.json"
MONTH=$(date +%Y-%m)

mkdir -p "$HISTORY_DIR"

python3 << PYEOF
import json
import os
from datetime import datetime, timezone

month = "$MONTH"
history_dir = "$HISTORY_DIR"
output_path = "$OUTPUT_FILE"

# Collect all daily stats files for this month
monthly_data = []
if os.path.exists(history_dir):
    for fname in sorted(os.listdir(history_dir)):
        if fname.startswith(f"daily-{month}") and fname.endswith(".json"):
            with open(os.path.join(history_dir, fname)) as f:
                monthly_data.append(json.load(f))

if not monthly_data:
    # No historical data yet — use current readings if available
    current_path = os.path.join(os.path.dirname(history_dir), "readings", "current.json")
    if os.path.exists(current_path):
        with open(current_path) as f:
            current = json.load(f)
        monthly_data = [{"date": month + "-01", "readings": current.get("readings", [])}]

# Aggregate by parameter across all days
by_param = {}
for day_data in monthly_data:
    readings = day_data.get("readings", day_data.get("parameters", {}))
    if isinstance(readings, list):
        for r in readings:
            param = r.get("parameter")
            value = r.get("value")
            if param and value is not None:
                if param not in by_param:
                    by_param[param] = []
                by_param[param].append(float(value))

monthly_stats = {}
for param, values in by_param.items():
    if values:
        sorted_vals = sorted(values)
        p90_idx = int(len(values) * 0.9)
        monthly_stats[param] = {
            "sample_count": len(values),
            "min": round(min(values), 4),
            "max": round(max(values), 4),
            "avg": round(sum(values) / len(values), 4),
            "p90": round(sorted_vals[p90_idx], 4)
        }

output = {
    "month": month,
    "days_with_data": len(monthly_data),
    "parameters": monthly_stats,
    "aggregated_at": datetime.now(timezone.utc).isoformat()
}

with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"Monthly aggregation complete: {len(monthly_stats)} parameters, {len(monthly_data)} days of data")
PYEOF
