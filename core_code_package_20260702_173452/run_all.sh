#!/bin/bash
# ============================================================
# Parallel data generation for ship radiated noise dataset
# Usage: bash run_all.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Ship Radiated Noise: Parallel Generation ==="
echo "Script dir : $SCRIPT_DIR"
echo ""

# Check octave
if ! command -v octave &> /dev/null; then
    echo "ERROR: octave not found. Install with:"
    echo "  sudo apt update && sudo apt install -y octave octave-signal"
    exit 1
fi

echo "[$(date '+%H:%M:%S')] Launching 5 class jobs..."

mkdir -p logs

octave --no-gui main_generate_dataset.m underwater_target  > logs/underwater_target.log  2>&1 &
PID1=$!
octave --no-gui main_generate_dataset.m fishing_boat       > logs/fishing_boat.log       2>&1 &
PID2=$!
octave --no-gui main_generate_dataset.m cargo_ship         > logs/cargo_ship.log         2>&1 &
PID3=$!
octave --no-gui main_generate_dataset.m cruise_ship        > logs/cruise_ship.log        2>&1 &
PID4=$!
octave --no-gui main_generate_dataset.m warship            > logs/warship.log            2>&1 &
PID5=$!

echo "PIDs: underwater_target=$PID1 fishing_boat=$PID2 cargo_ship=$PID3 cruise_ship=$PID4 warship=$PID5"
echo ""
echo "[$(date '+%H:%M:%S')] Waiting for all jobs to complete..."

FAILED=0
for pid in $PID1 $PID2 $PID3 $PID4 $PID5; do
    wait $pid || FAILED=1
done

echo "[$(date '+%H:%M:%S')] All jobs finished."
if [ $FAILED -eq 0 ]; then
    echo "=== SUCCESS ==="
else
    echo "=== Some jobs FAILED - check logs/ directory ==="
fi
