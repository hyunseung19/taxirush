"""Synthesizes a short, seamlessly-looping chiptune-style chase BGM as a WAV file.

Run with: python tools/generate_bgm.py
Output:   assets/audio/bgm.wav
"""
import math
import struct
import wave

SR = 44100
BPM = 150
BEAT = 60.0 / BPM          # quarter-note duration (s)
EIGHTH = BEAT / 2
BAR = BEAT * 4

# 4 chords x 2 bars = 8 bars total loop.
# (bass root Hz, [arpeggio note Hz, ...])
CHORDS = [
    (55.00,  [220.00, 261.63, 329.63]),   # A minor
    (43.65,  [174.61, 220.00, 261.63]),   # F major
    (65.41,  [261.63, 329.63, 392.00]),   # C major
    (49.00,  [196.00, 246.94, 293.66]),   # G major
]
BARS_PER_CHORD = 2
LOOP_BARS = len(CHORDS) * BARS_PER_CHORD
LOOP_SECONDS = LOOP_BARS * BAR
N = int(LOOP_SECONDS * SR)


def square(freq, t):
    return 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0


def triangle(freq, t):
    phase = (t * freq) % 1.0
    return 4 * abs(phase - 0.5) - 1.0


def env_decay(t_in_note, dur, attack=0.005, decay_k=6.0):
    if t_in_note < attack:
        return t_in_note / attack
    return math.exp(-decay_k * (t_in_note - attack))


def noise(seed_state):
    # tiny xorshift PRNG, deterministic, no numpy/random-module surprises
    x = seed_state[0]
    x ^= (x << 13) & 0xFFFFFFFF
    x ^= (x >> 17)
    x ^= (x << 5) & 0xFFFFFFFF
    x &= 0xFFFFFFFF
    seed_state[0] = x
    return (x / 0xFFFFFFFF) * 2.0 - 1.0


def main():
    samples = [0.0] * N
    rng_state = [0x12345678]

    for i in range(N):
        t = i / SR
        bar_idx = int(t // BAR) % LOOP_BARS
        chord_idx = (bar_idx // BARS_PER_CHORD) % len(CHORDS)
        bass_hz, arp = CHORDS[chord_idx]
        t_in_bar = t % BAR
        t_in_beat = t_in_bar % BEAT
        beat_idx = int(t_in_bar // BEAT)
        t_in_eighth = t_in_bar % EIGHTH
        eighth_idx = int(t_in_bar // EIGHTH)

        s = 0.0

        # Bass: one square pulse per beat, soft decay envelope.
        bass_env = env_decay(t_in_beat, BEAT, attack=0.005, decay_k=3.5)
        s += 0.30 * bass_env * square(bass_hz, t)

        # Lead arpeggio: triangle wave, one note per eighth note.
        lead_hz = arp[eighth_idx % len(arp)]
        lead_env = env_decay(t_in_eighth, EIGHTH, attack=0.003, decay_k=9.0)
        s += 0.22 * lead_env * triangle(lead_hz, t)

        # Kick drum on beats 0 and 2 — short pitch-dropping thump.
        if beat_idx in (0, 2) and t_in_beat < 0.12:
            k_env = math.exp(-28.0 * t_in_beat)
            k_freq = 110.0 * math.exp(-18.0 * t_in_beat)
            s += 0.55 * k_env * math.sin(2 * math.pi * k_freq * t_in_beat)

        # Hi-hat: short noise tick on every eighth note.
        if t_in_eighth < 0.025:
            h_env = math.exp(-90.0 * t_in_eighth)
            s += 0.16 * h_env * noise(rng_state)

        samples[i] = s

    # Normalize & convert to 16-bit PCM.
    peak = max(1e-6, max(abs(x) for x in samples))
    scale = 0.92 / peak
    pcm = bytearray()
    for x in samples:
        v = int(max(-1.0, min(1.0, x * scale)) * 32767)
        pcm += struct.pack('<h', v)

    with wave.open('assets/audio/bgm.wav', 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(bytes(pcm))

    print(f'Wrote assets/audio/bgm.wav  ({LOOP_SECONDS:.2f}s loop, {N} samples)')


if __name__ == '__main__':
    main()
