FROM debian:bookworm-slim

LABEL maintainer="audiodrop"
LABEL description="Audio recording container with automatic audio capture"

# Install system dependencies for audio recording
RUN apt-get update && apt-get install -y --no-install-recommends \
    alsa-utils \
    pulseaudio-utils \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy application files
COPY entrypoint.sh .

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Create recordings directory
RUN mkdir -p /recordings

# Environment variables with defaults
ENV AUDIO_CHANNELS=1
ENV AUDIO_RATE=44100
ENV RECORD_DURATION=60
ENV OUTPUT_DIR=/recordings

# Volume for recordings
VOLUME ["/recordings"]

# Entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
