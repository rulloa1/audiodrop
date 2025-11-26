#!/bin/bash
# Entrypoint script for the audio recording container

set -e

echo "=========================================="
echo "AudioDrop - Automatic Audio Recording"
echo "=========================================="
echo "Starting at: $(date)"
echo ""

# Create recordings directory if it doesn't exist
OUTPUT_DIR="${OUTPUT_DIR:-/recordings}"
mkdir -p "${OUTPUT_DIR}"

# Configuration
CHANNELS="${AUDIO_CHANNELS:-1}"
RATE="${AUDIO_RATE:-44100}"
DURATION="${RECORD_DURATION:-60}"

# Display configuration
echo "Configuration:"
echo "  - Channels: ${CHANNELS}"
echo "  - Sample Rate: ${RATE}"
echo "  - Recording Duration: ${DURATION}s per file"
echo "  - Output Directory: ${OUTPUT_DIR}"
echo ""

# Function to handle cleanup on exit
cleanup() {
    echo ""
    echo "Received shutdown signal, stopping recording..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start continuous recording
echo "Starting continuous audio recording..."
echo ""

while true; do
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    FILENAME="${OUTPUT_DIR}/recording_${TIMESTAMP}.wav"
    
    echo "Recording: ${FILENAME}"
    
    # Use arecord to capture audio
    # -D default: use default audio device
    # -f S16_LE: 16-bit signed little-endian format
    # -c: number of channels
    # -r: sample rate
    # -d: duration in seconds
    # -t wav: output format
    arecord -D default \
        -f S16_LE \
        -c "${CHANNELS}" \
        -r "${RATE}" \
        -d "${DURATION}" \
        -t wav \
        "${FILENAME}" 2>&1 || {
            echo "Warning: Recording failed, retrying in 5 seconds..."
            sleep 5
            continue
        }
    
    echo "Recording saved: ${FILENAME}"
done
