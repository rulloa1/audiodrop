#!/usr/bin/env python3
"""
Audio Streaming Client

This script connects to the audio server and plays the received audio stream.
"""

import socket
import subprocess
import sys
import signal
import argparse


def play_audio_stream(host, port, sample_rate=44100, channels=2, format_type='s16le'):
    """
    Connect to audio server and play the stream.

    Args:
        host: Server host address
        port: Server port number
        sample_rate: Audio sample rate
        channels: Number of audio channels
        format_type: Audio format
    """
    client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Create playback process using aplay
    play_cmd = [
        'aplay',
        '-f', format_type.replace('le', '_LE').upper(),
        '-r', str(sample_rate),
        '-c', str(channels),
        '-t', 'raw',
        '-'
    ]

    play_process = None

    try:
        print(f"Connecting to {host}:{port}...")
        client_socket.connect((host, port))
        print(f"Connected! Streaming audio...")

        play_process = subprocess.Popen(play_cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
        chunk_size = 4096

        while True:
            audio_data = client_socket.recv(chunk_size)
            if not audio_data:
                print("Server closed connection")
                break
            try:
                play_process.stdin.write(audio_data)
                play_process.stdin.flush()
            except BrokenPipeError:
                break

    except ConnectionRefusedError:
        print(f"Could not connect to {host}:{port}. Is the server running?")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nStopping playback...")
    finally:
        if play_process:
            play_process.terminate()
            play_process.wait()
        client_socket.close()


def main():
    parser = argparse.ArgumentParser(description='Audio Streaming Client')
    parser.add_argument('host', help='Server host address')
    parser.add_argument('--port', type=int, default=5555, help='Server port (default: 5555)')
    parser.add_argument('--sample-rate', type=int, default=44100, help='Sample rate in Hz (default: 44100)')
    parser.add_argument('--channels', type=int, default=2, choices=[1, 2], help='Audio channels (default: 2)')

    args = parser.parse_args()

    # Handle signals gracefully
    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))

    play_audio_stream(args.host, args.port, args.sample_rate, args.channels)


if __name__ == '__main__':
    main()
