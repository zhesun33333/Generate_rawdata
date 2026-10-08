#!/bin/bash
# ============================================================
# Parallel data generation for DataGen0608 (pulse + comm signals)
# Usage: bash run_all.sh [max_concurrent]
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MAX_JOBS=${1:-8}
echo "=== DataGen0608: Parallel Signal Generation ==="
echo "Script dir : $SCRIPT_DIR"
echo "Max concurrent jobs: $MAX_JOBS"
echo ""

mkdir -p logs

# Check octave
if ! command -v octave &> /dev/null; then
    echo "ERROR: octave not found. Install with:"
    echo "  sudo apt update && sudo apt install -y octave octave-signal octave-communications octave-image"
    exit 1
fi

echo "[$(date '+%H:%M:%S')] Launching pulse signal jobs..."
octave --no-gui build_pure_pulse_dataset.m CW   > logs/pulse_CW.log   2>&1 &
PID_CW=$!
octave --no-gui build_pure_pulse_dataset.m LFM  > logs/pulse_LFM.log  2>&1 &
PID_LFM=$!
octave --no-gui build_pure_pulse_dataset.m HFM  > logs/pulse_HFM.log  2>&1 &
PID_HFM=$!

echo "[$(date '+%H:%M:%S')] Launching communication signal jobs..."
octave --no-gui build_pure_comm_dataset.m 2FSK  > logs/comm_2FSK.log  2>&1 &
PID_2FSK=$!
octave --no-gui build_pure_comm_dataset.m 4FSK  > logs/comm_4FSK.log  2>&1 &
PID_4FSK=$!
octave --no-gui build_pure_comm_dataset.m BPSK  > logs/comm_BPSK.log  2>&1 &
PID_BPSK=$!
octave --no-gui build_pure_comm_dataset.m QPSK  > logs/comm_QPSK.log  2>&1 &
PID_QPSK=$!
octave --no-gui build_pure_comm_dataset.m OFDM  > logs/comm_OFDM.log  2>&1 &
PID_OFDM=$!

echo ""
echo "PIDs: CW=$PID_CW LFM=$PID_LFM HFM=$PID_HFM"
echo "PIDs: 2FSK=$PID_2FSK 4FSK=$PID_4FSK BPSK=$PID_BPSK QPSK=$PID_QPSK OFDM=$PID_OFDM"
echo ""
echo "[$(date '+%H:%M:%S')] Waiting for all jobs to complete..."

FAILED=0
for pid in $PID_CW $PID_LFM $PID_HFM $PID_2FSK $PID_4FSK $PID_BPSK $PID_QPSK $PID_OFDM; do
    wait $pid || FAILED=1
done

echo "[$(date '+%H:%M:%S')] All jobs finished."
if [ $FAILED -eq 0 ]; then
    echo "=== SUCCESS ==="
else
    echo "=== Some jobs FAILED - check logs/ directory ==="
fi
