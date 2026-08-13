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
RETRY_WAIT_SECS=5
DISK_WAIT_SECS=30

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
info() { log "INFO  $*"; }
warn() { log "WARN  $*"; }
err()  { log "ERROR $*" >&2; }

print_banner() {
    echo "=========================================="
    echo " AudioDrop – Automatic Audio Recording"
    echo "=========================================="
}

list_devices() {
    echo ""
    echo "Available ALSA capture devices:"
    echo "─────────────────────────────────"
    arecord -l 2>&1 || echo "(No capture devices found)"
    echo ""
    echo "Tip: set AUDIO_DEVICE=hw:<card>,<device> (e.g. hw:0,0)"
    echo ""
}

validate_config() {
    local valid=true

    if ! [[ "${CHANNELS}" =~ ^[0-9]+$ ]] || [ "${CHANNELS}" -lt 1 ] || [ "${CHANNELS}" -gt 8 ]; then
        err "AUDIO_CHANNELS must be between 1 and 8 (got '${CHANNELS}')"
        valid=false
    fi

    if ! [[ "${RATE}" =~ ^[0-9]+$ ]] || [ "${RATE}" -lt 8000 ] || [ "${RATE}" -gt 192000 ]; then
        err "AUDIO_RATE must be between 8000 and 192000 (got '${RATE}')"
        valid=false
    fi

    case "${FORMAT}" in
        S16_LE|S24_LE|S32_LE) ;;
        *)
            err "AUDIO_FORMAT must be S16_LE, S24_LE, or S32_LE (got '${FORMAT}')"
            valid=false
            ;;
    esac

    if ! [[ "${DURATION}" =~ ^[0-9]+$ ]] || [ "${DURATION}" -lt 1 ]; then
        err "RECORD_DURATION must be a positive integer (got '${DURATION}')"
        valid=false
    fi

    if ! [[ "${MIN_DISK_MB}" =~ ^[0-9]+$ ]] || [ "${MIN_DISK_MB}" -lt 1 ]; then
        err "MIN_DISK_MB must be a positive integer (got '${MIN_DISK_MB}')"
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
        warn "Low disk space – ${avail_kb} KB available (minimum ${MIN_DISK_MB} MB)"
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
            info "Removing empty recording: ${file}"
            rm -f "${file}"
        fi
    fi
}

format_bytes() {
    local bytes="$1"
    if [ "${bytes}" -ge $((1024 * 1024)) ]; then
        printf "%d MB" $(( bytes / 1024 / 1024 ))
    elif [ "${bytes}" -ge 1024 ]; then
        printf "%d KB" $(( bytes / 1024 ))
    else
        printf "%d B" "${bytes}"
    fi
}

# ---------------------------------------------------------------------------
# Signal handling – terminate the running arecord process cleanly
# ---------------------------------------------------------------------------
cleanup() {
    info "Received shutdown signal, stopping recording..."
    if [ -n "${ARECORD_PID}" ] && kill -0 "${ARECORD_PID}" 2>/dev/null; then
        kill "${ARECORD_PID}" 2>/dev/null
        wait "${ARECORD_PID}" 2>/dev/null || true
    fi
    remove_if_empty "${RECORDING_FILE}"
    info "AudioDrop stopped."
    exit 0
}

trap cleanup SIGINT SIGTERM

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
print_banner

# Special mode: list available audio devices then exit
if [ "${DEVICE}" = "list" ]; then
    list_devices
    exit 0
fi

validate_config

mkdir -p "${OUTPUT_DIR}"

info "Configuration:"
info "  Channels       : ${CHANNELS}"
info "  Sample rate    : ${RATE} Hz"
info "  Format         : ${FORMAT}"
info "  Segment length : ${DURATION}s"
info "  Audio device   : ${DEVICE}"
info "  Output dir     : ${OUTPUT_DIR}"
info "  Min disk space : ${MIN_DISK_MB} MB"
info ""
info "Starting continuous audio recording..."

SEGMENT=0
TOTAL_SAVED=0
while true; do
    SEGMENT=$((SEGMENT + 1))
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    RECORDING_FILE="${OUTPUT_DIR}/recording_${TIMESTAMP}.wav"

    if ! check_disk_space; then
        info "Pausing ${DISK_WAIT_SECS}s until disk space is available..."
        sleep "${DISK_WAIT_SECS}"
        continue
    fi

    info "[segment ${SEGMENT}] Recording → ${RECORDING_FILE}"

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
            file_size=$(stat -c%s "${RECORDING_FILE}" 2>/dev/null || echo 0)
            TOTAL_SAVED=$((TOTAL_SAVED + 1))
            info "[segment ${SEGMENT}] Saved $(basename "${RECORDING_FILE}") ($(format_bytes "${file_size}")) – total saved: ${TOTAL_SAVED}"
        fi
    else
        remove_if_empty "${RECORDING_FILE}"
        warn "Recording failed, retrying in ${RETRY_WAIT_SECS} seconds..."
        sleep "${RETRY_WAIT_SECS}"
    fi

    ARECORD_PID=""
done
