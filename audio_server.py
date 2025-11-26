#!/usr/bin/env python3
"""
Audio Capture and Streaming Server

This script captures audio from a microphone and streams it over TCP
to any connected client on the network.
"""

import socket
import subprocess
import sys
import os
import signal
import argparse


def get_audio_stream(sample_rate=44100, channels=2, format_type='s16le'):
    """
    Create an audio capture subprocess using ALSA (arecord).

    Args:
        sample_rate: Audio sample rate in Hz
        channels: Number of audio channels (1=mono, 2=stereo)
        format_type: Audio format (s16le, s32le, etc.)

    Returns:
        subprocess.Popen: Audio capture process
    """
    cmd = [
        'arecord',
        '-f', format_type.replace('le', '_LE').upper(),
        '-r', str(sample_rate),
        '-c', str(channels),
        '-t', 'raw',
        '-D', os.environ.get('AUDIO_DEVICE', 'default'),
        '-'
    ]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)


def start_server(host='0.0.0.0', port=5555, sample_rate=44100, channels=2):
    """
    Start the audio streaming server.

    Args:
        host: Host address to bind to
        port: Port number to listen on
        sample_rate: Audio sample rate
        channels: Number of audio channels
    """
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        server_socket.bind((host, port))
        server_socket.listen(5)
        print(f"Audio server listening on {host}:{port}")
        print(f"Sample rate: {sample_rate} Hz, Channels: {channels}")

        while True:
            print("Waiting for client connection...")
            client_socket, client_address = server_socket.accept()
            print(f"Client connected: {client_address}")

            audio_process = None
            try:
                audio_process = get_audio_stream(sample_rate, channels)
                chunk_size = 4096

                while True:
                    audio_data = audio_process.stdout.read(chunk_size)
                    if not audio_data:
                        break
                    try:
                        client_socket.sendall(audio_data)
                    except (BrokenPipeError, ConnectionResetError):
                        print(f"Client {client_address} disconnected")
                        break

            except Exception as e:
                print(f"Error streaming to {client_address}: {e}")
            finally:
                if audio_process:
                    audio_process.terminate()
                    audio_process.wait()
                client_socket.close()
                print(f"Connection closed: {client_address}")

    except KeyboardInterrupt:
        print("\nShutting down server...")
    finally:
        server_socket.close()


def main():
    parser = argparse.ArgumentParser(description='Audio Capture and Streaming Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=5555, help='Port to listen on (default: 5555)')
    parser.add_argument('--sample-rate', type=int, default=44100, help='Sample rate in Hz (default: 44100)')
    parser.add_argument('--channels', type=int, default=2, choices=[1, 2], help='Audio channels (default: 2)')

    args = parser.parse_args()

    # Handle signals gracefully
    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))

    start_server(args.host, args.port, args.sample_rate, args.channels)


if __name__ == '__main__':
    main()
