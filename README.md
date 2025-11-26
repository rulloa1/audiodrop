# AudioDrop

A Docker-based audio recording tool that automatically captures audio from the system's microphone.

## Features

- Automatic audio recording on container startup
- Configurable recording parameters (channels, sample rate, duration)
- Continuous recording with automatic file segmentation
- WAV file output with timestamp-based naming
- Graceful shutdown handling

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop recording
docker-compose down
```

### Using Docker Directly

```bash
# Build the image
docker build -t audiodrop .

# Run the container
docker run -d \
  --name audiodrop \
  --device /dev/snd:/dev/snd \
  --privileged \
  -v $(pwd)/recordings:/recordings \
  audiodrop
```

## Configuration

The following environment variables can be used to configure the recorder:

| Variable | Default | Description |
|----------|---------|-------------|
| `AUDIO_CHANNELS` | 1 | Number of audio channels (1=mono, 2=stereo) |
| `AUDIO_RATE` | 44100 | Sample rate in Hz |
| `RECORD_DURATION` | 60 | Duration of each recording segment in seconds |
| `OUTPUT_DIR` | /recordings | Directory where recordings are saved |

### Example with Custom Configuration

```bash
docker run -d \
  --name audiodrop \
  --device /dev/snd:/dev/snd \
  --privileged \
  -e AUDIO_CHANNELS=2 \
  -e AUDIO_RATE=48000 \
  -e RECORD_DURATION=120 \
  -v $(pwd)/recordings:/recordings \
  audiodrop
```

## Output

Recordings are saved as WAV files in the `/recordings` directory (or the configured `OUTPUT_DIR`). Files are named with timestamps:

```
recording_20241126_120530.wav
recording_20241126_120630.wav
...
```

## Requirements

- Docker
- Docker Compose (optional)
- Audio input device (microphone)

## Notes

- The container requires access to audio devices (`--device /dev/snd:/dev/snd`)
- For PulseAudio systems, you may need to mount the PulseAudio socket
- The `--privileged` flag may be required for audio device access
