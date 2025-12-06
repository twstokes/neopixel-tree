#!/usr/bin/env python3
"""
Christmas audio-reactive control for NeoPixel tree.
Uses Christmas colors and patterns that react to audio amplitude.
"""

import socket
import numpy as np
import pyaudio
import threading
import time
import sys
from pydub import AudioSegment
from scipy import signal
import librosa
from config import UDP_IP, UDP_PORT, PIXEL_COUNT
import commands
import random

# Christmas color schemes
CHRISTMAS_COLORS = {
    'red': [255, 0, 0],
    'green': [0, 255, 0],
    'white': [255, 255, 255],
    'gold': [255, 215, 0],
    'blue': [0, 100, 255],
}

# Audio analysis configuration
AMPLITUDE_SCALE = 5000
NOISE_FLOOR = 100
DEFAULT_LATENCY_OFFSET = 0.01
ANALYSIS_CHUNK_SIZE = 2048

# Effect thresholds (0-1 normalized amplitude)
QUIET_THRESHOLD = 0.15      # Gentle twinkling
MEDIUM_THRESHOLD = 0.4      # Alternating colors
LOUD_THRESHOLD = 0.7        # Theater chase
VERY_LOUD_THRESHOLD = 0.85  # Full tree pulses

# Visualization modes
MODE_EFFECTS = 'effects'      # Original pattern-based mode
MODE_VU_METER = 'vu_meter'    # VU meter mode (amplitude -> pixel count)
MODE_BEAT = 'beat'            # Beat detection mode (switch effects on beat)

def calculate_amplitude(audio_data):
    """Calculate RMS amplitude from audio data."""
    if len(audio_data) == 0:
        return 0.0
    rms = np.sqrt(np.mean(np.abs(audio_data.astype(np.float64))**2))
    if np.isnan(rms) or np.isinf(rms):
        return 0.0
    return rms

def normalize_amplitude(amplitude):
    """Normalize amplitude to 0-1 range."""
    adjusted = max(0, amplitude - NOISE_FLOOR)
    normalized = min(1.0, adjusted / AMPLITUDE_SCALE)
    return normalized

def calculate_frequency_bands(audio_data, sample_rate):
    """
    Calculate amplitude for three frequency bands: bass, mid, treble.
    Returns (bass_amp, mid_amp, treble_amp) normalized to 0-1.
    """
    if len(audio_data) == 0:
        return 0.0, 0.0, 0.0

    # Convert to float for processing
    audio_float = audio_data.astype(np.float64)

    # Design bandpass filters
    nyquist = sample_rate / 2

    # Bass: 20-250 Hz
    bass_low, bass_high = 20, 250
    if bass_high < nyquist:
        sos_bass = signal.butter(4, [bass_low, bass_high], btype='band', fs=sample_rate, output='sos')
        bass_filtered = signal.sosfilt(sos_bass, audio_float)
        bass_amp = np.sqrt(np.mean(bass_filtered**2))
    else:
        bass_amp = 0.0

    # Mid: 250-2000 Hz
    mid_low, mid_high = 250, 2000
    if mid_high < nyquist:
        sos_mid = signal.butter(4, [mid_low, mid_high], btype='band', fs=sample_rate, output='sos')
        mid_filtered = signal.sosfilt(sos_mid, audio_float)
        mid_amp = np.sqrt(np.mean(mid_filtered**2))
    else:
        mid_amp = 0.0

    # Treble: 2000 Hz - Nyquist
    treble_low = 2000
    if treble_low < nyquist:
        sos_treble = signal.butter(4, treble_low, btype='high', fs=sample_rate, output='sos')
        treble_filtered = signal.sosfilt(sos_treble, audio_float)
        treble_amp = np.sqrt(np.mean(treble_filtered**2))
    else:
        treble_amp = 0.0

    # Normalize each band
    bass_norm = normalize_amplitude(bass_amp)
    mid_norm = normalize_amplitude(mid_amp)
    treble_norm = normalize_amplitude(treble_amp)

    return bass_norm, mid_norm, treble_norm

def detect_beats(audio_path):
    """
    Detect beats in the audio file using librosa.
    Returns (beat_times, tempo, beat_frames).
    """
    print("Detecting beats and tempo...")

    # Load audio with librosa
    y, sr = librosa.load(audio_path, sr=None)

    # Detect tempo and beats
    tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr)

    # Convert beat frames to time
    beat_times = librosa.frames_to_time(beat_frames, sr=sr)

    # Extract scalar tempo value (librosa returns numpy array)
    tempo_value = float(tempo) if hasattr(tempo, '__iter__') else tempo

    print(f"Detected tempo: {tempo_value:.1f} BPM")
    print(f"Found {len(beat_times)} beats")

    return beat_times, tempo_value, sr

def analyze_audio_file(audio_path, mode=MODE_EFFECTS):
    """Pre-analyze audio file to extract amplitude data."""
    print(f"Analyzing audio file: {audio_path}")

    audio = AudioSegment.from_file(audio_path)

    if audio.channels > 1:
        audio = audio.set_channels(1)

    sample_rate = audio.frame_rate
    duration = len(audio) / 1000.0

    print(f"Sample rate: {sample_rate} Hz")
    print(f"Channels: {audio.channels}")
    print(f"Duration: {duration:.2f} seconds")

    audio_data = np.array(audio.get_array_of_samples())

    if audio.sample_width == 1:
        audio_data = ((audio_data.astype(np.int32) - 128) * 256).astype(np.int16)
    elif audio.sample_width == 2:
        audio_data = audio_data.astype(np.int16)
    elif audio.sample_width == 4:
        audio_data = (audio_data / 65536).astype(np.int16)

    # Analyze timeline based on mode
    if mode == MODE_BEAT:
        # Detect beats for beat mode
        beat_times, tempo, sr = detect_beats(audio_path)
        timeline = beat_times

    elif mode == MODE_VU_METER:
        # Analyze frequency bands for VU meter mode
        print("Analyzing frequency bands (bass, mid, treble)...")
        timeline = []
        for i in range(0, len(audio_data), ANALYSIS_CHUNK_SIZE):
            chunk = audio_data[i:i + ANALYSIS_CHUNK_SIZE]
            bass, mid, treble = calculate_frequency_bands(chunk, sample_rate)
            timestamp = i / sample_rate
            timeline.append((timestamp, bass, mid, treble))
        print(f"Analyzed {len(timeline)} frequency band points")
    else:
        # Analyze overall amplitude for effects mode
        timeline = []
        for i in range(0, len(audio_data), ANALYSIS_CHUNK_SIZE):
            chunk = audio_data[i:i + ANALYSIS_CHUNK_SIZE]
            amplitude = calculate_amplitude(chunk)
            normalized = normalize_amplitude(amplitude)
            timestamp = i / sample_rate
            timeline.append((timestamp, normalized))
        print(f"Analyzed {len(timeline)} audio points")

    print()

    return timeline, audio

def create_christmas_pattern(normalized_amp):
    """Create a Christmas color pattern based on amplitude."""
    pattern = []

    if normalized_amp < QUIET_THRESHOLD:
        # Quiet: Soft alternating red and green with some white
        for i in range(PIXEL_COUNT):
            if i % 3 == 0:
                pattern.extend(CHRISTMAS_COLORS['red'])
            elif i % 3 == 1:
                pattern.extend(CHRISTMAS_COLORS['green'])
            else:
                pattern.extend(CHRISTMAS_COLORS['white'])

    elif normalized_amp < MEDIUM_THRESHOLD:
        # Medium: Red, green, and gold alternating
        for i in range(PIXEL_COUNT):
            if i % 4 == 0:
                pattern.extend(CHRISTMAS_COLORS['red'])
            elif i % 4 == 1:
                pattern.extend(CHRISTMAS_COLORS['green'])
            elif i % 4 == 2:
                pattern.extend(CHRISTMAS_COLORS['gold'])
            else:
                pattern.extend(CHRISTMAS_COLORS['white'])

    elif normalized_amp < LOUD_THRESHOLD:
        # Loud: More varied pattern with blues
        for i in range(PIXEL_COUNT):
            if i % 5 == 0:
                pattern.extend(CHRISTMAS_COLORS['red'])
            elif i % 5 == 1:
                pattern.extend(CHRISTMAS_COLORS['green'])
            elif i % 5 == 2:
                pattern.extend(CHRISTMAS_COLORS['blue'])
            elif i % 5 == 3:
                pattern.extend(CHRISTMAS_COLORS['gold'])
            else:
                pattern.extend(CHRISTMAS_COLORS['white'])

    else:
        # Very loud: Randomized sparkle effect
        for i in range(PIXEL_COUNT):
            color_choice = random.choice(list(CHRISTMAS_COLORS.values()))
            pattern.extend(color_choice)

    return pattern

def send_fill_pattern(sock, pattern):
    """Send fill_pattern command with color data."""
    pixel_count = len(pattern) // 3
    payload = [commands.fill_pattern, pixel_count] + pattern
    sock.sendto(bytes(payload), (UDP_IP, UDP_PORT))

def send_theater_chase(sock, color, repeat=1):
    """Send theater chase effect."""
    payload = [commands.theater_chase, repeat] + color
    sock.sendto(bytes(payload), (UDP_IP, UDP_PORT))

def send_fill_color(sock, color):
    """Send solid color fill."""
    payload = [commands.fill_color] + color
    sock.sendto(bytes(payload), (UDP_IP, UDP_PORT))

def get_effect_name(normalized_amp):
    """Get effect name based on amplitude."""
    if normalized_amp < QUIET_THRESHOLD:
        return 'Quiet'
    elif normalized_amp < MEDIUM_THRESHOLD:
        return 'Medium'
    elif normalized_amp < LOUD_THRESHOLD:
        return 'Loud'
    elif normalized_amp < VERY_LOUD_THRESHOLD:
        return 'Very Loud'
    else:
        return 'EXTREME'

def get_effect_color(normalized_amp):
    """Get ANSI color code for effect level."""
    if normalized_amp < QUIET_THRESHOLD:
        return '\033[36m'  # Cyan
    elif normalized_amp < MEDIUM_THRESHOLD:
        return '\033[32m'  # Green
    elif normalized_amp < LOUD_THRESHOLD:
        return '\033[33m'  # Yellow
    elif normalized_amp < VERY_LOUD_THRESHOLD:
        return '\033[35m'  # Magenta
    else:
        return '\033[91m'  # Bright Red

def create_alternating_pattern():
    """Create alternating red and green pattern."""
    pattern = []
    for i in range(PIXEL_COUNT):
        if i % 2 == 0:
            pattern.extend(CHRISTMAS_COLORS['red'])
        else:
            pattern.extend(CHRISTMAS_COLORS['green'])
    return pattern

def create_vu_meter_pattern(bass_amp, mid_amp, treble_amp):
    """
    Create VU meter pattern with frequency bands.
    Each third of the tree represents a different frequency band.
    bass_amp, mid_amp, treble_amp are normalized 0-1 values.
    """
    pattern = []

    # Calculate pixels per band
    pixels_per_band = PIXEL_COUNT // 3
    remainder = PIXEL_COUNT % 3

    # Bass section (bottom third) - Green
    bass_pixels = int(bass_amp * pixels_per_band)
    for i in range(pixels_per_band):
        if i < bass_pixels:
            pattern.extend(CHRISTMAS_COLORS['green'])
        else:
            pattern.extend([0, 0, 0])

    # Mid section (middle third) - Gold
    mid_pixels = int(mid_amp * pixels_per_band)
    for i in range(pixels_per_band):
        if i < mid_pixels:
            pattern.extend(CHRISTMAS_COLORS['gold'])
        else:
            pattern.extend([0, 0, 0])

    # Treble section (top third) - Red
    treble_pixels_count = pixels_per_band + remainder  # Add remainder to treble
    treble_pixels = int(treble_amp * treble_pixels_count)
    for i in range(treble_pixels_count):
        if i < treble_pixels:
            pattern.extend(CHRISTMAS_COLORS['red'])
        else:
            pattern.extend([0, 0, 0])

    return pattern

def christmas_effect_sender(timeline, start_time, stop_event, visualizer_data, mode, latency_offset):
    """Thread function to send Christmas effects based on audio."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    prev_effect = None
    effect_counter = 0

    # Define Christmas effects for beat mode
    beat_effects = [
        ('red_fill', lambda s: send_fill_color(s, CHRISTMAS_COLORS['red'])),
        ('green_fill', lambda s: send_fill_color(s, CHRISTMAS_COLORS['green'])),
        ('gold_fill', lambda s: send_fill_color(s, CHRISTMAS_COLORS['gold'])),
        ('white_fill', lambda s: send_fill_color(s, CHRISTMAS_COLORS['white'])),
        ('red_chase', lambda s: send_theater_chase(s, CHRISTMAS_COLORS['red'], repeat=1)),
        ('green_chase', lambda s: send_theater_chase(s, CHRISTMAS_COLORS['green'], repeat=1)),
        ('alternating', lambda s: send_fill_pattern(s, create_alternating_pattern())),
    ]

    for idx, data in enumerate(timeline):
        if stop_event.is_set():
            break

        if mode == MODE_BEAT:
            # Beat mode - data is just beat timestamp
            beat_time = data

            # Update visualizer
            visualizer_data['current_index'] = idx
            visualizer_data['current_time'] = beat_time
            visualizer_data['beat_number'] = idx + 1

            # Calculate when to send (accounting for latency)
            send_time = start_time + beat_time - latency_offset
            wait_time = send_time - time.time()
            if wait_time > 0:
                time.sleep(wait_time)

            # Switch to next effect on each beat
            effect_name, effect_func = beat_effects[effect_counter % len(beat_effects)]
            effect_func(sock)
            visualizer_data['current_effect'] = effect_name
            effect_counter += 1

        elif mode == MODE_VU_METER:
            # Unpack frequency band data
            timestamp, bass_amp, mid_amp, treble_amp = data

            # Update visualizer data
            visualizer_data['current_index'] = idx
            visualizer_data['current_time'] = timestamp
            visualizer_data['bass_amp'] = bass_amp
            visualizer_data['mid_amp'] = mid_amp
            visualizer_data['treble_amp'] = treble_amp

            # Calculate when to send (accounting for latency)
            send_time = start_time + timestamp - latency_offset
            wait_time = send_time - time.time()
            if wait_time > 0:
                time.sleep(wait_time)

            # Create and send frequency band pattern
            pattern = create_vu_meter_pattern(bass_amp, mid_amp, treble_amp)
            send_fill_pattern(sock, pattern)

        else:
            # Unpack amplitude data
            timestamp, normalized_amp = data

            # Update visualizer data
            visualizer_data['current_index'] = idx
            visualizer_data['current_amp'] = normalized_amp
            visualizer_data['current_time'] = timestamp

            # Calculate when to send (accounting for latency)
            send_time = start_time + timestamp - latency_offset
            wait_time = send_time - time.time()
            if wait_time > 0:
                time.sleep(wait_time)
            # Effects mode - original behavior
            # Choose effect based on amplitude
            if normalized_amp < QUIET_THRESHOLD:
                effect = 'quiet'
                pattern = create_christmas_pattern(normalized_amp)
                send_fill_pattern(sock, pattern)

            elif normalized_amp < MEDIUM_THRESHOLD:
                effect = 'medium'
                pattern = create_christmas_pattern(normalized_amp)
                send_fill_pattern(sock, pattern)

            elif normalized_amp < LOUD_THRESHOLD:
                effect = 'loud'
                pattern = create_christmas_pattern(normalized_amp)
                send_fill_pattern(sock, pattern)

            elif normalized_amp < VERY_LOUD_THRESHOLD:
                effect = 'very_loud'
                # Theater chase with alternating Christmas colors
                if effect_counter % 2 == 0:
                    send_theater_chase(sock, CHRISTMAS_COLORS['red'], repeat=1)
                else:
                    send_theater_chase(sock, CHRISTMAS_COLORS['green'], repeat=1)
                effect_counter += 1

            else:
                effect = 'extreme'
                # Full tree pulses with bright colors
                colors = [CHRISTMAS_COLORS['red'], CHRISTMAS_COLORS['green'],
                         CHRISTMAS_COLORS['gold'], CHRISTMAS_COLORS['white']]
                send_fill_color(sock, colors[effect_counter % len(colors)])
                effect_counter += 1

            prev_effect = effect

    sock.close()

def visualizer_thread(timeline, stop_event, visualizer_data, mode, tempo=None, latency_offset=DEFAULT_LATENCY_OFFSET):
    """Thread to display real-time visualizer."""
    RESET = '\033[0m'
    LOOKAHEAD_COUNT = 30  # Show next 30 points

    while not stop_event.is_set():
        current_idx = visualizer_data.get('current_index', 0)
        current_time = visualizer_data.get('current_time', 0.0)

        # Clear previous output
        print('\033[2J\033[H', end='')  # Clear screen and move to top

        # Header
        if mode == MODE_BEAT:
            mode_text = f"BEAT MODE ({tempo:.1f} BPM)"
        elif mode == MODE_VU_METER:
            mode_text = "VU METER MODE (Frequency Bands)"
        else:
            mode_text = "EFFECTS MODE"

        print("🎄 " + "="*70 + " 🎄")
        print(f"   CHRISTMAS AUDIO VISUALIZER - {mode_text} - Time: {current_time:.2f}s")
        print("🎄 " + "="*70 + " 🎄\n")

        # Latency info
        print(f"Latency Offset: {latency_offset * 1000:.1f} ms\n")

        # Current effect info
        if mode == MODE_BEAT:
            # Beat mode display
            beat_number = visualizer_data.get('beat_number', 0)
            current_effect = visualizer_data.get('current_effect', 'none')
            total_beats = len(timeline)

            print(f"Current Beat: {beat_number}/{total_beats}")
            print(f"Current Effect: {current_effect}")
            print(f"Tempo: {tempo:.1f} BPM\n")

            # Show beat indicator
            beats_to_show = 16
            beat_bar = ""
            for i in range(beats_to_show):
                if beat_number > 0 and i == (beat_number - 1) % beats_to_show:
                    beat_bar += "🔴"
                else:
                    beat_bar += "⚪"
            print(f"Beat Pattern: {beat_bar}\n")

        elif mode == MODE_VU_METER:
            # VU meter specific display with frequency bands
            bass_amp = visualizer_data.get('bass_amp', 0.0)
            mid_amp = visualizer_data.get('mid_amp', 0.0)
            treble_amp = visualizer_data.get('treble_amp', 0.0)

            pixels_per_band = PIXEL_COUNT // 3
            remainder = PIXEL_COUNT % 3

            bass_pixels = int(bass_amp * pixels_per_band)
            mid_pixels = int(mid_amp * pixels_per_band)
            treble_pixels = int(treble_amp * (pixels_per_band + remainder))

            print(f"Bass   (20-250Hz)  : {bass_amp:5.1%} - {bass_pixels:3d}/{pixels_per_band} pixels")
            print(f"Mid    (250-2kHz)  : {mid_amp:5.1%} - {mid_pixels:3d}/{pixels_per_band} pixels")
            print(f"Treble (2kHz+)     : {treble_amp:5.1%} - {treble_pixels:3d}/{pixels_per_band + remainder} pixels\n")

            # Build VU meter bar with frequency bands
            GREEN = '\033[32m'
            YELLOW = '\033[33m'
            RED = '\033[91m'

            # Bass section (green)
            bass_bar = GREEN
            for i in range(pixels_per_band):
                bass_bar += "█" if i < bass_pixels else "░"
            bass_bar += RESET

            # Mid section (yellow/gold)
            mid_bar = YELLOW
            for i in range(pixels_per_band):
                mid_bar += "█" if i < mid_pixels else "░"
            mid_bar += RESET

            # Treble section (red)
            treble_bar = RED
            for i in range(pixels_per_band + remainder):
                treble_bar += "█" if i < treble_pixels else "░"
            treble_bar += RESET

            print(f"Tree:")
            print(f"  Bass:   [{bass_bar}]")
            print(f"  Mid:    [{mid_bar}]")
            print(f"  Treble: [{treble_bar}]\n")
        else:
            # Effects mode display
            current_amp = visualizer_data.get('current_amp', 0.0)
            effect_name = get_effect_name(current_amp)
            effect_color = get_effect_color(current_amp)
            print(f"Current Effect: {effect_color}{effect_name}{RESET}")
            print(f"Amplitude: {current_amp:.2%}\n")

            # Amplitude bar
            bar_width = 60
            filled = int(current_amp * bar_width)
            bar = '█' * filled + '░' * (bar_width - filled)
            print(f"[{effect_color}{bar}{RESET}]\n")

            # Threshold markers
            print("Thresholds:")
            print(f"  Quiet    : {QUIET_THRESHOLD:.0%}  |  Medium: {MEDIUM_THRESHOLD:.0%}  |  Loud: {LOUD_THRESHOLD:.0%}  |  Very Loud: {VERY_LOUD_THRESHOLD:.0%}  |  Extreme: {VERY_LOUD_THRESHOLD:.0%}+\n")

        # Upcoming preview
        print("Upcoming (next few seconds):")
        print("┌" + "─" * 68 + "┐")

        # Show next LOOKAHEAD_COUNT points
        for i in range(LOOKAHEAD_COUNT):
            idx = current_idx + i
            if idx >= len(timeline):
                break

            if mode == MODE_BEAT:
                # Show upcoming beats
                beat_time = timeline[idx]
                relative_time = beat_time - current_time

                indicator = "→" if i == 0 else " "
                beat_marker = "🎵"

                print(f"│{indicator} +{relative_time:4.1f}s {beat_marker} Beat #{idx + 1}                                             │")

            elif mode == MODE_VU_METER:
                timestamp, bass, mid, treble = timeline[idx]
                relative_time = timestamp - current_time

                # Create mini bars for each frequency band
                GREEN = '\033[32m'
                YELLOW = '\033[33m'
                RED = '\033[91m'

                bar_width = 12
                bass_bar = GREEN + ('█' * int(bass * bar_width)).ljust(bar_width, '░') + RESET
                mid_bar = YELLOW + ('█' * int(mid * bar_width)).ljust(bar_width, '░') + RESET
                treble_bar = RED + ('█' * int(treble * bar_width)).ljust(bar_width, '░') + RESET

                indicator = "→" if i == 0 else " "
                print(f"│{indicator} +{relative_time:4.1f}s B:[{bass_bar}] M:[{mid_bar}] T:[{treble_bar}]│")

            else:
                timestamp, amp = timeline[idx]
                relative_time = timestamp - current_time

                # Create mini bar for this point
                mini_bar_width = 40
                mini_filled = int(amp * mini_bar_width)
                mini_bar = '█' * mini_filled + '░' * (mini_bar_width - mini_filled)

                # Color based on effect level
                color = get_effect_color(amp)
                effect = get_effect_name(amp)

                indicator = "→" if i == 0 else " "
                print(f"│{indicator} +{relative_time:4.1f}s [{color}{mini_bar}{RESET}] {amp:5.1%} {effect:10s}│")

        print("└" + "─" * 68 + "┘")

        print("\n🎄 Press Ctrl+C to stop")

        time.sleep(0.1)  # Update 10 times per second

def play_audio_with_christmas_effects(audio_path, mode=MODE_EFFECTS):
    """Play audio file and sync Christmas effects to the tree."""
    timeline, audio = analyze_audio_file(audio_path, mode)

    # Get tempo if in beat mode
    tempo = None
    if mode == MODE_BEAT:
        # Re-analyze to get tempo (timeline is just beat times)
        _, tempo, _ = detect_beats(audio_path)

    # Initialize PyAudio
    p = pyaudio.PyAudio()

    # Open audio stream
    stream = p.open(
        format=p.get_format_from_width(audio.sample_width),
        channels=audio.channels,
        rate=audio.frame_rate,
        output=True
    )

    # Create stop event and shared visualizer data
    stop_event = threading.Event()
    visualizer_data = {
        'current_index': 0,
        'current_amp': 0.0,
        'current_time': 0.0,
        'bass_amp': 0.0,
        'mid_amp': 0.0,
        'treble_amp': 0.0,
        'beat_number': 0,
        'current_effect': 'none'
    }
    latency_offset = DEFAULT_LATENCY_OFFSET

    # Start effect sender thread
    start_time = time.time()
    effect_thread = threading.Thread(
        target=christmas_effect_sender,
        args=(timeline, start_time, stop_event, visualizer_data, mode, latency_offset)
    )
    effect_thread.start()

    # Start visualizer thread
    viz_thread = threading.Thread(
        target=visualizer_thread,
        args=(timeline, stop_event, visualizer_data, mode, tempo, latency_offset)
    )
    viz_thread.start()

    # Brief delay to let visualizer start
    time.sleep(0.2)

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

        # Wait for effect thread to finish
        effect_thread.join()

    except KeyboardInterrupt:
        print("\n\n🎄 Stopping Christmas show")
        stop_event.set()
    finally:
        # Cleanup
        stop_event.set()
        stream.stop_stream()
        stream.close()
        p.terminate()

        effect_thread.join(timeout=1.0)
        viz_thread.join(timeout=1.0)

    print("\n\n🎄 Merry Christmas! Show complete!")

def main():
    if len(sys.argv) < 2:
        print("Usage: python christmas_audio.py <path_to_audio_file> [mode]")
        print("\nModes:")
        print("  effects   - Pattern-based effects (default)")
        print("  vu        - VU meter mode (frequency bands: bass/mid/treble)")
        print("  beat      - Beat detection mode (switch effects on beat)")
        print("\nSupported formats: WAV, MP3, FLAC, OGG, and more")
        print("\nConfiguration:")
        print(f"  Tree: {UDP_IP}:{UDP_PORT}")
        print(f"  Latency offset: {DEFAULT_LATENCY_OFFSET * 1000:.0f}ms")
        print(f"  Pixels: {PIXEL_COUNT}")
        print("\nVU Meter Mode:")
        print("  - Bottom 1/3 (Green):  Bass (20-250 Hz)")
        print("  - Middle 1/3 (Gold):   Mid (250-2000 Hz)")
        print("  - Top 1/3 (Red):       Treble (2000+ Hz)")
        print("\nBeat Mode:")
        print("  - Detects tempo and beats in the song")
        print("  - Switches between different Christmas effects on each beat")
        print("  - Effects include solid colors, theater chase, and patterns")
        print("\nExamples:")
        print("  python christmas_audio.py song.wav")
        print("  python christmas_audio.py song.wav vu")
        print("  python christmas_audio.py song.wav beat")
        sys.exit(1)

    audio_path = sys.argv[1]

    # Parse mode argument
    mode = MODE_EFFECTS  # Default
    if len(sys.argv) > 2:
        mode_arg = sys.argv[2].lower()
        if mode_arg in ['vu', 'vu_meter', 'meter']:
            mode = MODE_VU_METER
        elif mode_arg in ['effects', 'effect']:
            mode = MODE_EFFECTS
        elif mode_arg in ['beat', 'beats', 'tempo']:
            mode = MODE_BEAT
        else:
            print(f"Unknown mode: {mode_arg}")
            print("Valid modes: effects, vu, beat")
            sys.exit(1)

    try:
        play_audio_with_christmas_effects(audio_path, mode)
    except FileNotFoundError:
        print(f"Error: Audio file not found: {audio_path}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
