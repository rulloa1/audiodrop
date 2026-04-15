FROM debian:bookworm-slim

LABEL maintainer="audiodrop"
LABEL description="Audio recording container with automatic audio capture"

# Install system dependencies and create non-root user in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    alsa-utils \
    pulseaudio-utils \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 audiodrop \
    && useradd --uid 1000 --gid audiodrop --shell /bin/bash --create-home audiodrop \
    && mkdir -p /recordings && chown audiodrop:audiodrop /recordings

WORKDIR /app

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Environment variables with defaults
ENV AUDIO_CHANNELS=1 \
    AUDIO_RATE=44100 \
    RECORD_DURATION=60 \
    OUTPUT_DIR=/recordings \
    AUDIO_DEVICE=default \
    AUDIO_FORMAT=S16_LE \
    MIN_DISK_MB=100

# Volume for recordings
VOLUME ["/recordings"]

# Healthcheck: verify arecord is actively running
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pgrep -x arecord > /dev/null || exit 1

USER audiodrop

ENTRYPOINT ["/app/entrypoint.sh"]
