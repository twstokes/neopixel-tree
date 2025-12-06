#!/usr/bin/env python3
"""
Audio file brightness control for NeoPixel tree.
Plays an audio file (WAV, MP3, etc.) and synchronizes tree brightness with audio amplitude.
Pre-sends brightness commands to account for network latency.
"""

import socket
import numpy as np
import pyaudio
import threading
import time
import sys
from pydub import AudioSegment
from config import UDP_IP, UDP_PORT
import commands

# Brightness mapping configuration
MIN_BRIGHTNESS = 10
MAX_BRIGHTNESS = 255

# Amplitude threshold configuration
NOISE_FLOOR = 100
AMPLITUDE_SCALE = 5000

# Latency compensation (seconds)
# Adjust this value if brightness changes appear late/early
LATENCY_OFFSET = 0.01

# Analysis window size (in audio frames)
ANALYSIS_CHUNK_SIZE = 2048

def calculate_amplitude(audio_data):
    """Calculate RMS amplitude from audio data."""
    if len(audio_data) == 0:
        return 0.0
    rms = np.sqrt(np.mean(np.abs(audio_data.astype(np.float64))**2))
    if np.isnan(rms) or np.isinf(rms):
        return 0.0
    return rms

def map_amplitude_to_brightness(amplitude):
    """Map audio amplitude to brightness value (0-255)."""
    adjusted_amplitude = max(0, amplitude - NOISE_FLOOR)
    brightness = (adjusted_amplitude / AMPLITUDE_SCALE) * MAX_BRIGHTNESS
    brightness = max(MIN_BRIGHTNESS, min(MAX_BRIGHTNESS, brightness))
    return int(brightness)

def analyze_audio_file(audio_path):
    """Pre-analyze audio file to extract amplitude data at each time point."""
    print(f"Analyzing audio file: {audio_path}")

    # Load audio file using pydub (supports WAV, MP3, and more)
    audio = AudioSegment.from_file(audio_path)

    # Convert to mono if stereo
    if audio.channels > 1:
        audio = audio.set_channels(1)

    sample_rate = audio.frame_rate
    duration = len(audio) / 1000.0  # pydub uses milliseconds

    print(f"Sample rate: {sample_rate} Hz")
    print(f"Channels: {audio.channels}")
    print(f"Duration: {duration:.2f} seconds")
    print(f"Sample width: {audio.sample_width} bytes")

    # Get raw audio data as numpy array
    audio_data = np.array(audio.get_array_of_samples())

    # Convert to int16 if needed
    if audio.sample_width == 1:
        # 8-bit unsigned to 16-bit signed
        audio_data = ((audio_data.astype(np.int32) - 128) * 256).astype(np.int16)
    elif audio.sample_width == 2:
        # Already 16-bit
        audio_data = audio_data.astype(np.int16)
    elif audio.sample_width == 4:
        # 32-bit to 16-bit
        audio_data = (audio_data / 65536).astype(np.int16)

    # Calculate amplitude for each chunk
    brightness_timeline = []

    for i in range(0, len(audio_data), ANALYSIS_CHUNK_SIZE):
        chunk = audio_data[i:i + ANALYSIS_CHUNK_SIZE]
        amplitude = calculate_amplitude(chunk)
        brightness = map_amplitude_to_brightness(amplitude)
        timestamp = i / sample_rate
        brightness_timeline.append((timestamp, brightness))

    print(f"Analyzed {len(brightness_timeline)} brightness points")
    print()

    return brightness_timeline, audio

def brightness_sender(brightness_timeline, start_time, stop_event):
    """Thread function to send brightness commands with latency compensation."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    for timestamp, brightness in brightness_timeline:
        if stop_event.is_set():
            break

        # Calculate when to send (accounting for latency)
        send_time = start_time + timestamp - LATENCY_OFFSET

        # Wait until it's time to send
        wait_time = send_time - time.time()
        if wait_time > 0:
            time.sleep(wait_time)

        # Send brightness command
        payload = [commands.brightness, brightness]
        sock.sendto(bytes(payload), (UDP_IP, UDP_PORT))

    sock.close()

def play_audio_with_brightness(audio_path):
    """Play audio file and sync brightness to the tree."""
    # Analyze the audio file first
    brightness_timeline, audio = analyze_audio_file(audio_path)

    # Initialize PyAudio
    p = pyaudio.PyAudio()

    # Open audio stream
    stream = p.open(
        format=p.get_format_from_width(audio.sample_width),
        channels=audio.channels,
        rate=audio.frame_rate,
        output=True
    )

    # Create stop event for brightness thread
    stop_event = threading.Event()

    # Start brightness sender thread
    start_time = time.time()
    brightness_thread = threading.Thread(
        target=brightness_sender,
        args=(brightness_timeline, start_time, stop_event)
    )
    brightness_thread.start()

    print(f"Playing {audio_path}")
    print(f"Network latency compensation: {LATENCY_OFFSET * 1000:.0f}ms")
    print("Press Ctrl+C to stop\n")

    # Get raw audio data
    audio_data = audio.raw_data

    # Play audio in chunks
    chunk_size = 1024 * audio.sample_width * audio.channels
    try:
        for i in range(0, len(audio_data), chunk_size):
            if stop_event.is_set():
                break
            chunk = audio_data[i:i + chunk_size]
            stream.write(chunk)

        # Wait for brightness thread to finish
        brightness_thread.join()

    except KeyboardInterrupt:
        print("\n\nStopping playback")
        stop_event.set()
    finally:
        # Cleanup
        stream.stop_stream()
        stream.close()
        p.terminate()

        # Wait for brightness thread
        stop_event.set()
        brightness_thread.join(timeout=1.0)

    print("Playback complete")

def main():
    if len(sys.argv) < 2:
        print("Usage: python wav_brightness.py <path_to_audio_file>")
        print("\nSupported formats: WAV, MP3, FLAC, OGG, and more")
        print("\nConfiguration:")
        print(f"  Tree: {UDP_IP}:{UDP_PORT}")
        print(f"  Latency offset: {LATENCY_OFFSET * 1000:.0f}ms")
        print(f"  Brightness range: {MIN_BRIGHTNESS}-{MAX_BRIGHTNESS}")
        print("\nAdjust LATENCY_OFFSET in the script if brightness appears out of sync")
        sys.exit(1)

    audio_path = sys.argv[1]

    try:
        play_audio_with_brightness(audio_path)
    except FileNotFoundError:
        print(f"Error: Audio file not found: {audio_path}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
