# audiodrop

A Docker-based audio recording and streaming solution that captures audio and sends it to another computer on your network.

## Features

- 🎤 Captures audio from microphone using ALSA
- 📡 Streams audio over TCP to any connected client
- 🐳 Docker containerized for easy deployment
- 🔧 Configurable sample rate and channels

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Build and start the audio server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down
```

### Using Docker Directly

```bash
# Build the image
docker build -t audiodrop .

# Run the container
docker run -d \
  --name audiodrop \
  -p 5555:5555 \
  --device /dev/snd:/dev/snd \
  --group-add audio \
  audiodrop
```

### Running Without Docker

```bash
# On the machine with the microphone (server)
python3 audio_server.py --host 0.0.0.0 --port 5555

# On the receiving machine (client)
python3 audio_client.py <server-ip> --port 5555
```

## Requirements

### Server (Audio Source)
- Python 3.x
- ALSA utilities (`alsa-utils`)
- A working microphone

### Client (Audio Receiver)
- Python 3.x
- ALSA utilities (`alsa-utils`)
- Audio output device (speakers/headphones)

## Configuration

### Server Options

| Option | Default | Description |
|--------|---------|-------------|
| `--host` | 0.0.0.0 | Host address to bind to |
| `--port` | 5555 | Port to listen on |
| `--sample-rate` | 44100 | Audio sample rate in Hz |
| `--channels` | 2 | Number of audio channels (1 or 2) |

### Client Options

| Argument | Default | Description |
|----------|---------|-------------|
| `host` | (required) | Server IP address |
| `--port` | 5555 | Server port |
| `--sample-rate` | 44100 | Audio sample rate in Hz |
| `--channels` | 2 | Number of audio channels (1 or 2) |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AUDIO_DEVICE` | default | ALSA audio device to use |

## Network Usage

To receive audio on another computer:

```bash
# Install dependencies (Debian/Ubuntu)
sudo apt-get install python3 alsa-utils

# Connect to the audio stream
python3 audio_client.py 192.168.1.100 --port 5555
```

Replace `192.168.1.100` with the IP address of the machine running the audio server.

## Troubleshooting

### No audio devices found
Make sure the container has access to audio devices:
```bash
docker run --device /dev/snd:/dev/snd --group-add audio audiodrop
```

### Permission denied
Add your user to the `audio` group:
```bash
sudo usermod -a -G audio $USER
# Log out and back in for changes to take effect
```

### List available audio devices
```bash
arecord -l  # List capture devices
aplay -l    # List playback devices
```

## Security Note

By default, the server binds to `0.0.0.0`, which accepts connections from any network interface. For a more restricted setup, use `--host 127.0.0.1` to only allow local connections, or use firewall rules to control access.

## License

MIT
