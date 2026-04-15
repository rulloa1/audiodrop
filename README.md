# AudioDrop

A Docker-based audio recording tool that automatically captures audio from the system's microphone.

## Features

- Automatic audio recording on container startup
- Configurable recording parameters (channels, sample rate, format, duration)
- Continuous recording with automatic file segmentation
- WAV file output with timestamp-based naming
- Graceful shutdown handling (in-progress recordings are cleaned up)
- Input validation and structured logging
- Disk-space monitoring – pauses recording when space is low
- Runs as a non-root user inside the container
- Container health check via `HEALTHCHECK`

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build and start the container
docker compose up -d

# View logs
docker compose logs -f

# Stop recording
docker compose down
```

### Using Docker Directly

```bash
# Build the image
docker build -t audiodrop .

# Run the container
docker run -d \
  --name audiodrop \
  --device /dev/snd:/dev/snd \
  --group-add audio \
  -v $(pwd)/recordings:/recordings \
  audiodrop
```

## Configuration

The following environment variables can be used to configure the recorder:

| Variable | Default | Description |
|----------|---------|-------------|
| `AUDIO_CHANNELS` | `1` | Number of audio channels (1–8) |
| `AUDIO_RATE` | `44100` | Sample rate in Hz (8000–192000) |
| `RECORD_DURATION` | `60` | Duration of each recording segment in seconds |
| `OUTPUT_DIR` | `/recordings` | Directory where recordings are saved |
| `AUDIO_DEVICE` | `default` | ALSA device name (e.g. `hw:0,0`) |
| `AUDIO_FORMAT` | `S16_LE` | Sample format (`S16_LE`, `S24_LE`, `S32_LE`) |
| `MIN_DISK_MB` | `100` | Minimum free disk space (MB) before pausing |

### Example with Custom Configuration

```bash
docker run -d \
  --name audiodrop \
  --device /dev/snd:/dev/snd \
  --group-add audio \
  -e AUDIO_CHANNELS=2 \
  -e AUDIO_RATE=48000 \
  -e AUDIO_FORMAT=S24_LE \
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

## Architecture

```
┌──────────────────────────────────┐
│  Docker Container (non-root)     │
│                                  │
│  entrypoint.sh                   │
│    ├─ validate configuration     │
│    ├─ check disk space           │
│    └─ loop:                      │
│         arecord ──► .wav file    │
│                                  │
│  /dev/snd  ◄── host audio device │
│  /recordings ◄── mounted volume  │
└──────────────────────────────────┘
```

## Requirements

- Docker
- Docker Compose (optional)
- Audio input device (microphone)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `audio open error: No such file or directory` | Ensure `--device /dev/snd:/dev/snd` is passed and a microphone is connected. |
| `Permission denied` on `/dev/snd/*` | Add `--group-add audio` or verify the host audio group GID matches. |
| Empty or 44-byte WAV files | The recorder auto-removes these. Check logs for the underlying error. |
| Recording pauses unexpectedly | Disk space may be below `MIN_DISK_MB`. Free space or raise the threshold. |
| PulseAudio not detected | Mount the PulseAudio socket and set `PULSE_SERVER` (see `docker-compose.yml` comments). |

## Notes

- The container requires access to audio devices (`--device /dev/snd:/dev/snd`)
- Add the container to the audio group with `--group-add audio` for device access
- For PulseAudio systems, you may need to mount the PulseAudio socket
- The container runs as a non-root user (`audiodrop`, UID 1000) for improved security
