#!/bin/bash
# Entrypoint script for the audio recording container
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration (with defaults)
# ---------------------------------------------------------------------------
OUTPUT_DIR="${OUTPUT_DIR:-/recordings}"
CHANNELS="${AUDIO_CHANNELS:-1}"
RATE="${AUDIO_RATE:-44100}"
DURATION="${RECORD_DURATION:-60}"
DEVICE="${AUDIO_DEVICE:-default}"
FORMAT="${AUDIO_FORMAT:-S16_LE}"
MIN_DISK_MB="${MIN_DISK_MB:-100}"

ARECORD_PID=""
RECORDING_FILE=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

validate_config() {
    local valid=true

    if ! [[ "${CHANNELS}" =~ ^[0-9]+$ ]] || [ "${CHANNELS}" -lt 1 ] || [ "${CHANNELS}" -gt 8 ]; then
        log "ERROR: AUDIO_CHANNELS must be between 1 and 8 (got '${CHANNELS}')"
        valid=false
    fi

    if ! [[ "${RATE}" =~ ^[0-9]+$ ]] || [ "${RATE}" -lt 8000 ] || [ "${RATE}" -gt 192000 ]; then
        log "ERROR: AUDIO_RATE must be between 8000 and 192000 (got '${RATE}')"
        valid=false
    fi

    if ! [[ "${DURATION}" =~ ^[0-9]+$ ]] || [ "${DURATION}" -lt 1 ]; then
        log "ERROR: RECORD_DURATION must be a positive integer (got '${DURATION}')"
        valid=false
    fi

    if [ "${valid}" = false ]; then
        exit 1
    fi
}

check_disk_space() {
    local avail_kb
    avail_kb=$(df --output=avail "${OUTPUT_DIR}" 2>/dev/null | tail -1 | tr -d ' ')
    if [ -n "${avail_kb}" ] && [ "${avail_kb}" -lt $((MIN_DISK_MB * 1024)) ]; then
        log "WARNING: Low disk space – ${avail_kb} KB available (minimum ${MIN_DISK_MB} MB)"
        return 1
    fi
    return 0
}

remove_if_empty() {
    local file="$1"
    if [ -f "${file}" ]; then
        local size
        size=$(stat -c%s "${file}" 2>/dev/null || echo 0)
        if [ "${size}" -le 44 ]; then   # 44 bytes = WAV header only
            log "Removing empty recording: ${file}"
            rm -f "${file}"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Signal handling – terminate the running arecord process cleanly
# ---------------------------------------------------------------------------
cleanup() {
    log "Received shutdown signal, stopping recording..."
    if [ -n "${ARECORD_PID}" ] && kill -0 "${ARECORD_PID}" 2>/dev/null; then
        kill "${ARECORD_PID}" 2>/dev/null
        wait "${ARECORD_PID}" 2>/dev/null || true
    fi
    remove_if_empty "${RECORDING_FILE}"
    log "AudioDrop stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=========================================="
echo " AudioDrop – Automatic Audio Recording"
echo "=========================================="

validate_config

mkdir -p "${OUTPUT_DIR}"

log "Configuration:"
log "  Channels       : ${CHANNELS}"
log "  Sample rate    : ${RATE} Hz"
log "  Format         : ${FORMAT}"
log "  Segment length : ${DURATION}s"
log "  Audio device   : ${DEVICE}"
log "  Output dir     : ${OUTPUT_DIR}"
log "  Min disk space : ${MIN_DISK_MB} MB"
log ""
log "Starting continuous audio recording..."

SEGMENT=0
while true; do
    SEGMENT=$((SEGMENT + 1))
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RECORDING_FILE="${OUTPUT_DIR}/recording_${TIMESTAMP}.wav"

    if ! check_disk_space; then
        log "Pausing recording until disk space is available..."
        sleep 30
        continue
    fi

    log "[segment ${SEGMENT}] Recording → ${RECORDING_FILE}"

    arecord -D "${DEVICE}" \
        -f "${FORMAT}" \
        -c "${CHANNELS}" \
        -r "${RATE}" \
        -d "${DURATION}" \
        -t wav \
        "${RECORDING_FILE}" 2>&1 &
    ARECORD_PID=$!

    # Wait for arecord; if it fails the loop retries
    if wait "${ARECORD_PID}"; then
        remove_if_empty "${RECORDING_FILE}"
        if [ -f "${RECORDING_FILE}" ]; then
            local_size=$(stat -c%s "${RECORDING_FILE}" 2>/dev/null || echo "?")
            log "[segment ${SEGMENT}] Saved ${RECORDING_FILE} (${local_size} bytes)"
        fi
    else
        remove_if_empty "${RECORDING_FILE}"
        log "WARNING: Recording failed, retrying in 5 seconds..."
        sleep 5
    fi

    ARECORD_PID=""
done
