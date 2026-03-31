#!/usr/bin/env bash
# parse-sensors.sh — Simulate sensor data arrival for demo/testing
# In production this would interface with SCADA system or data logger API

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="$PROJECT_ROOT/data/readings/raw"
PROCESSED_DIR="$PROJECT_ROOT/data/readings/processed"

mkdir -p "$RAW_DIR" "$PROCESSED_DIR"

# Check if there are any raw files to process
RAW_COUNT=$(find "$RAW_DIR" -name "*.json" -o -name "*.csv" 2>/dev/null | wc -l | tr -d ' ')

if [ "$RAW_COUNT" -eq 0 ]; then
  # Generate a sample sensor reading file for demo purposes
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  DATE=$(date +%Y-%m-%d)
  HOUR=$(date +%H)

  cat > "$RAW_DIR/sensors-${DATE}-${HOUR}.json" << EOF
{
  "ingestion_timestamp": "$TIMESTAMP",
  "source": "SCADA_system",
  "readings": [
    {
      "sensor_id": "TRB-TP-01",
      "location": "treatment_plant_effluent",
      "parameter": "turbidity",
      "value": 0.12,
      "unit": "NTU",
      "timestamp": "$TIMESTAMP"
    },
    {
      "sensor_id": "CL2-TP-01",
      "location": "treatment_plant_effluent",
      "parameter": "chlorine_residual",
      "value": 0.95,
      "unit": "mg/L",
      "timestamp": "$TIMESTAMP"
    },
    {
      "sensor_id": "PH-TP-01",
      "location": "treatment_plant_effluent",
      "parameter": "ph",
      "value": 7.6,
      "unit": "pH",
      "timestamp": "$TIMESTAMP"
    },
    {
      "sensor_id": "TEMP-TP-01",
      "location": "treatment_plant_effluent",
      "parameter": "temperature",
      "value": 18.5,
      "unit": "celsius",
      "timestamp": "$TIMESTAMP"
    },
    {
      "sensor_id": "CL2-DIST-01",
      "location": "distribution_entry_point",
      "parameter": "chlorine_residual",
      "value": 0.72,
      "unit": "mg/L",
      "timestamp": "$TIMESTAMP"
    },
    {
      "sensor_id": "TRB-DIST-01",
      "location": "distribution_entry_point",
      "parameter": "turbidity",
      "value": 0.18,
      "unit": "NTU",
      "timestamp": "$TIMESTAMP"
    }
  ]
}
EOF

  echo "Generated demo sensor file: sensors-${DATE}-${HOUR}.json"
  echo "Raw files ready: 1"
else
  echo "Found $RAW_COUNT raw sensor file(s) to process"
fi
