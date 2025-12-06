#!/usr/bin/env python3
"""
Audio-reactive brightness control for NeoPixel tree.
Adjusts tree brightness based on microphone input amplitude.
"""

import socket
import numpy as np
import pyaudio
from config import UDP_IP, UDP_PORT
import commands
import time

# Audio configuration
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 44100

# Brightness mapping configuration
MIN_BRIGHTNESS = 10
MAX_BRIGHTNESS = 255
SMOOTHING_FACTOR = 0.3  # Lower = smoother, higher = more responsive
UPDATE_INTERVAL = 0.05  # seconds between updates

# Amplitude threshold configuration
NOISE_FLOOR = 100  # Ignore quiet background noise
AMPLITUDE_SCALE = 5000  # Adjust based on your mic sensitivity

def calculate_amplitude(data):
    """Calculate RMS amplitude from audio data."""
    audio_data = np.frombuffer(data, dtype=np.int16)
    rms = np.sqrt(np.mean(np.abs(audio_data.astype(np.float64))**2))
    # Handle NaN or invalid values
    if np.isnan(rms) or np.isinf(rms):
        return 0.0
    return rms

def map_amplitude_to_brightness(amplitude):
    """Map audio amplitude to brightness value (0-255)."""
    # Subtract noise floor
    adjusted_amplitude = max(0, amplitude - NOISE_FLOOR)

    # Scale and clamp to brightness range
    brightness = (adjusted_amplitude / AMPLITUDE_SCALE) * MAX_BRIGHTNESS
    brightness = max(MIN_BRIGHTNESS, min(MAX_BRIGHTNESS, brightness))

    return int(brightness)

def main():
    # Initialize PyAudio
    p = pyaudio.PyAudio()

    # Open audio stream
    stream = p.open(
        format=FORMAT,
        channels=CHANNELS,
        rate=RATE,
        input=True,
        frames_per_buffer=CHUNK
    )

    # Initialize UDP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    print("Audio-reactive brightness control started")
    print(f"Listening to microphone and controlling tree at {UDP_IP}:{UDP_PORT}")
    print("Press Ctrl+C to stop")
    print()

    current_brightness = MIN_BRIGHTNESS

    try:
        while True:
            # Read audio data
            data = stream.read(CHUNK, exception_on_overflow=False)

            # Calculate amplitude
            amplitude = calculate_amplitude(data)

            # Map to brightness
            target_brightness = map_amplitude_to_brightness(amplitude)

            # Apply smoothing
            current_brightness = (
                SMOOTHING_FACTOR * target_brightness +
                (1 - SMOOTHING_FACTOR) * current_brightness
            )

            # Send brightness command
            brightness_value = int(current_brightness)
            payload = [commands.brightness, brightness_value]
            sock.sendto(bytes(payload), (UDP_IP, UDP_PORT))

            # Display status
            bar_length = int((brightness_value / MAX_BRIGHTNESS) * 40)
            bar = '█' * bar_length + '░' * (40 - bar_length)
            print(f'\rAmplitude: {int(amplitude):5d} | Brightness: {brightness_value:3d} | {bar}', end='', flush=True)

            time.sleep(UPDATE_INTERVAL)

    except KeyboardInterrupt:
        print("\n\nStopping audio-reactive brightness control")
    finally:
        # Cleanup
        stream.stop_stream()
        stream.close()
        p.terminate()
        sock.close()

if __name__ == "__main__":
    main()
