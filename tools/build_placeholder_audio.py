"""Generates the placeholder sounds in assets/audio (16-bit mono WAV, 44.1 kHz).

Every sound is synthesised here from sine waves and noise, so nothing in the
game's audio comes from a third party. Replace any file with a real recording
of the same name (or point its asset id somewhere else in the manifest).

    python tools/build_placeholder_audio.py

Needs only the Python standard library. Re-run Godot's import afterwards
(tools\\godot.ps1 --headless --import).
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
random.seed(7)


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def envelope(n, attack=0.005, release=0.5, curve=2.0):
    """Fast attack, then a decay shaped by `curve` over the rest."""
    a = max(1, int(RATE * attack))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1, n - a)
            out.append((1.0 - t) ** curve * (1.0 if release > 0 else 0.0))
    return out


def sweep(seconds, f0, f1, shape='sine', curve=1.0):
    """A tone gliding from f0 to f1."""
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        t = (i / n) ** curve
        f = f0 + (f1 - f0) * t
        phase += 2.0 * math.pi * f / RATE
        s = math.sin(phase)
        if shape == 'square':
            s = 1.0 if s >= 0 else -1.0
        elif shape == 'saw':
            s = (phase / math.pi) % 2.0 - 1.0
        out.append(s)
    return out


def noise(seconds, lowpass=1.0, lowpass_end=None):
    """White noise through a one-pole low-pass whose strength can move."""
    n = int(RATE * seconds)
    out = []
    y = 0.0
    for i in range(n):
        k = lowpass if lowpass_end is None else lowpass + (lowpass_end - lowpass) * i / n
        y += k * (random.uniform(-1.0, 1.0) - y)
        out.append(y)
    peak = max(1e-9, max(abs(v) for v in out))
    return [v / peak for v in out]


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def gain(a, g):
    return [x * g for x in a]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def shaped(track, attack=0.005, curve=2.0):
    return mul(track, envelope(len(track), attack, 1.0, curve))


def save(name, track, peak=0.85):
    os.makedirs(OUT, exist_ok=True)
    top = max(1e-9, max(abs(v) for v in track))
    scale = peak / top
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, v * scale)) * 32767)) for v in track))
    print('%-28s %.2f s' % (name + '.wav', len(track) / RATE))


def tone(seconds, f, shape='sine'):
    return sweep(seconds, f, f, shape)


def build():
    # --- weapons -----------------------------------------------------------
    save('weapon_laser', shaped(mix(sweep(0.13, 2100, 500), gain(sweep(0.13, 4200, 900), 0.3)), 0.002, 1.6))
    save('weapon_beam', shaped(mix(tone(0.22, 180, 'saw'), gain(tone(0.22, 1440), 0.35), gain(noise(0.22, 0.5), 0.2)), 0.02, 0.8), 0.6)
    save('weapon_plasma', shaped(mix(sweep(0.3, 520, 110), gain(noise(0.3, 0.25), 0.5)), 0.004, 1.8))
    save('weapon_plasma_heavy', shaped(mix(sweep(0.5, 320, 60), gain(noise(0.5, 0.15), 0.6)), 0.006, 1.6))
    save('weapon_kinetic', shaped(mix(noise(0.09, 0.7, 0.1), gain(sweep(0.09, 220, 70), 0.9)), 0.001, 2.2))
    save('weapon_cannon', shaped(mix(noise(0.22, 0.5, 0.05), sweep(0.22, 150, 45)), 0.001, 2.0))
    save('weapon_rail', shaped(mix(sweep(0.45, 3200, 180, curve=0.4), gain(noise(0.45, 0.9, 0.05), 0.7), gain(sweep(0.45, 90, 40), 0.8)), 0.001, 2.4))
    save('weapon_missile', shaped(mix(noise(0.55, 0.08, 0.5), gain(sweep(0.55, 160, 420), 0.25)), 0.03, 1.2), 0.7)
    save('weapon_flak', shaped(mix(noise(0.3, 0.6, 0.04), sweep(0.3, 120, 40)), 0.001, 1.8))
    save('weapon_emp', shaped(mix(sweep(0.55, 90, 1400, 'square', 2.0), gain(noise(0.55, 0.9), 0.25)), 0.01, 1.2), 0.6)
    save('weapon_arc', shaped(mul(noise(0.25, 0.95), [1.0 if random.random() > 0.35 else 0.0 for _ in range(int(RATE * 0.25))]), 0.002, 1.0), 0.55)
    save('weapon_singularity', shaped(mix(sweep(0.9, 240, 28, curve=0.6), gain(sweep(0.9, 60, 20), 0.9), gain(noise(0.9, 0.04), 0.5)), 0.02, 1.2))

    # --- explosions and impacts -------------------------------------------
    save('explosion_small', shaped(mix(noise(0.5, 0.35, 0.02), gain(sweep(0.5, 110, 40), 0.8)), 0.002, 2.4))
    save('explosion_medium', shaped(mix(noise(1.0, 0.25, 0.015), gain(sweep(1.0, 80, 30), 1.0)), 0.003, 2.2))
    save('explosion_large', shaped(mix(noise(2.0, 0.18, 0.008), gain(sweep(2.0, 60, 22), 1.2), gain(noise(2.0, 0.02), 0.6)), 0.005, 2.0))
    save('impact_shield', shaped(mix(sweep(0.3, 1500, 900), gain(tone(0.3, 2250), 0.4), gain(noise(0.3, 0.8), 0.12)), 0.002, 2.0), 0.6)
    save('impact_hull', shaped(mix(tone(0.32, 190, 'square'), gain(tone(0.32, 437), 0.5), gain(noise(0.32, 0.4, 0.05), 0.8)), 0.001, 2.6))
    save('enemy_hit', shaped(mix(tone(0.05, 900), gain(noise(0.05, 0.9), 0.4)), 0.001, 2.0), 0.35)
    save('enemy_laser', shaped(sweep(0.16, 900, 1700, 'square'), 0.003, 1.4), 0.4)

    # --- engines (loops; an exact number of cycles so they repeat cleanly) ---
    def loop(seconds, parts):
        n = int(RATE * seconds)
        out = [0.0] * n
        for f, g in parts:
            cycles = round(f * seconds)
            for i in range(n):
                out[i] += g * math.sin(2.0 * math.pi * cycles * i / n)
        return out
    save('enemy_engine', loop(2.0, [(70, 1.0), (140.5, 0.5), (211, 0.3), (3.5, 0.0)]), 0.5)
    save('enemy_engine_heavy', loop(3.0, [(38, 1.0), (57, 0.7), (76.33, 0.4), (114, 0.2)]), 0.6)

    # --- interface and alerts ---------------------------------------------
    save('ui_click', shaped(tone(0.04, 1300), 0.001, 2.0), 0.4)
    save('ui_buy', concat(shaped(tone(0.08, 880), 0.002, 1.5), shaped(tone(0.14, 1320), 0.002, 1.8)), 0.5)
    save('ui_deny', shaped(tone(0.18, 150, 'square'), 0.002, 1.2), 0.4)
    save('ui_power_tick', shaped(tone(0.035, 1900), 0.001, 2.0), 0.35)
    save('alert_shields_down', concat(shaped(tone(0.16, 880, 'square'), 0.003, 0.8), shaped(tone(0.16, 660, 'square'), 0.003, 0.8), shaped(tone(0.3, 440, 'square'), 0.003, 1.2)), 0.5)
    save('alert_shields_up', concat(shaped(tone(0.1, 660), 0.003, 0.8), shaped(tone(0.22, 990), 0.003, 1.4)), 0.5)
    save('alert_hull_critical', concat(*[concat(shaped(tone(0.11, 1000, 'square'), 0.002, 0.6), silence(0.07)) for _ in range(3)]), 0.5)
    save('alert_overheat', shaped(mix(tone(0.4, 220, 'saw'), gain(tone(0.4, 233, 'saw'), 0.8)), 0.005, 0.9), 0.45)
    save('alert_incoming', concat(*[shaped(sweep(0.14, 700, 1250), 0.004, 0.7) for _ in range(3)]), 0.5)
    save('stage_complete', concat(*[shaped(tone(0.14 if i < 3 else 0.5, f), 0.004, 1.4) for i, f in enumerate([523, 659, 784, 1047])]), 0.55)
    save('stage_failed', concat(*[shaped(tone(0.28 if i < 2 else 0.8, f, 'saw'), 0.004, 1.3) for i, f in enumerate([330, 262, 196])]), 0.5)

    save('music_ambient', ambient_music(), 0.8)


def ambient_music():
    """A slow four-chord pad (A minor, F, C, G), 32 s, that loops without a seam.

    Each chord swells in and out over its 8 s slot and overlaps its
    neighbours; the overlap wraps around the end of the file, so the last
    chord fades into the first. Notes sit between 110 and 660 Hz with a few
    harmonics, so the pad is audible on small speakers and headphones too.
    (The first version was a 55 Hz drone that most speakers could not play.)
    """
    seconds = 32.0
    n = int(RATE * seconds)
    out = [0.0] * n
    slot = n // 4
    overlap = int(RATE * 2.5)
    chords = [
        [110.0, 220.0, 261.63, 329.63, 440.0],   # A minor
        [87.31, 174.61, 220.0, 261.63, 349.23],  # F
        [130.81, 196.0, 261.63, 329.63, 392.0],  # C
        [98.0, 196.0, 246.94, 293.66, 392.0],    # G
    ]
    harmonics = [(1, 1.0), (2, 0.35), (3, 0.18), (4, 0.08)]
    span = slot + 2 * overlap
    window = [math.sin(math.pi * i / span) ** 2 for i in range(span)]
    for index, chord in enumerate(chords):
        start = index * slot - overlap
        for note_index, f in enumerate(chord):
            # Bass a little softer, the top a little softer still.
            level = 0.7 if note_index == 0 else (0.55 if note_index == len(chord) - 1 else 1.0)
            detune = 1.0 + 0.0015 * (note_index - 2)
            for multiple, weight in harmonics:
                w = 2.0 * math.pi * f * multiple * detune / RATE
                amp = level * weight
                for i in range(span):
                    out[(start + i) % n] += amp * window[i] * math.sin(w * i)
    # A slow breath over the whole loop (whole cycles, so it loops cleanly).
    for i in range(n):
        out[i] *= 0.8 + 0.2 * math.sin(2.0 * math.pi * 2.0 * i / n)
    return out


if __name__ == '__main__':
    build()
