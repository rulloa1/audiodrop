FROM python:3.11-slim

# Install ALSA utilities for audio capture
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    alsa-utils \
    libasound2 \
    libasound2-plugins \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application files
COPY audio_server.py .
COPY audio_client.py .

# Make scripts executable
RUN chmod +x audio_server.py audio_client.py

# Expose the default streaming port
EXPOSE 5555

# Default environment variables
ENV AUDIO_DEVICE=default

# Run the audio server by default
CMD ["python3", "audio_server.py"]
