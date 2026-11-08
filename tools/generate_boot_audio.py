"""Original retro startup: soft motor rise, disk seeks, diagnostic beeps, ready chord."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
DURATION = 4.4
rng = random.Random(83)
samples = []
filtered = 0.0
phase = 0.0

def tone(t, start, duration, frequency, gain):
    local = t - start
    if not 0 <= local < duration:
        return 0.0
    envelope = min(1.0, local / .008, (duration - local) / .04)
    # Rounded digital speaker tone, without a harsh full-band square wave.
    return gain * envelope * (math.sin(math.tau * frequency * local) + .15 * math.sin(math.tau * frequency * 3 * local))

for i in range(int(RATE * DURATION)):
    t = i / RATE
    phase += math.tau * (92 + 55 * min(t, 1.2) / 1.2) / RATE
    motor = min(t / .25, 1) * max(0, 1 - t / 3.7)
    value = .055 * motor * (math.sin(phase) + .25 * math.sin(phase * 2))
    value += .012 * motor * rng.uniform(-1, 1)
    for start in [.85, .94, 1.16, 1.27, 1.54, 1.61, 1.88, 2.02, 2.25, 2.38, 2.59, 2.77]:
        if 0 <= t - start < .035:
            value += .08 * math.exp(-(t - start) * 110) * rng.uniform(-1, 1)
    for start, freq in [(1.2, 660), (1.95, 784), (2.65, 988)]:
        value += tone(t, start, .085, freq, .11)
    for start, freq in [(3.40, 523.25), (3.52, 659.25), (3.64, 783.99)]:
        value += tone(t, start, .60, freq, .085)
    filtered += .28 * (value - filtered)
    fade = min(1, t / .01, (DURATION - t) / .05)
    samples.append(filtered * max(0, fade))
peak = max(map(abs, samples))
gain = 10 ** (-9 / 20) / peak
out = Path(__file__).resolve().parents[1] / 'audio' / 'retro_boot.wav'
with wave.open(str(out), 'wb') as wav:
    wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
    wav.writeframes(b''.join(struct.pack('<h', round(x * gain * 32767)) for x in samples))
print(f'{out}: {DURATION}s, mono, peak -9 dBFS, no clipping')
