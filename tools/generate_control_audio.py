"""Reproducible, original retro-future control sounds; Python standard library only.

One-shots have quiet zero crossings at both edges. Loops are written at exact frame
counts, have zero endpoint jumps and use cyclic musical release/delay tails.
"""
from __future__ import annotations

import array
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave
import zlib

RATE = 22050
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "audio" / "controls"


def buffer(seconds: float) -> list[float]:
    return [0.0] * round(seconds * RATE)


def smoothstep(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def tone(dst: list[float], at: float, duration: float, frequency: float,
         gain: float, end_frequency: float | None = None,
         attack: float = .005, release: float = .035,
         decay: float = 0.0, harmonic: float = .12,
         cyclic: bool = False) -> None:
    """A softly rounded old loudspeaker voice, with sample-continuous phase."""
    phase = 0.0
    count = max(1, round(duration * RATE))
    start = round(at * RATE)
    end_frequency = frequency if end_frequency is None else end_frequency
    for j in range(count):
        t = j / RATE
        p = j / max(1, count - 1)
        hz = frequency * (end_frequency / frequency) ** p
        phase += TAU * hz / RATE
        env = smoothstep(t / max(attack, 1 / RATE))
        env *= smoothstep((duration - t) / max(release, 1 / RATE))
        if decay:
            env *= math.exp(-decay * t)
        value = gain * env * (math.sin(phase) + harmonic * math.sin(phase * 3.0))
        index = start + j
        if cyclic:
            dst[index % len(dst)] += value
        elif 0 <= index < len(dst):
            dst[index] += value


def noise(dst: list[float], at: float, duration: float, gain: float,
          seed: int, cutoff: float = 1800.0, decay: float = 0.0,
          flutter: float = 0.0, attack: float = .004,
          release: float = .018) -> None:
    rng = random.Random(seed)
    alpha = 1.0 - math.exp(-TAU * cutoff / RATE)
    low = 0.0
    dc = 0.0
    start = round(at * RATE)
    for j in range(round(duration * RATE)):
        t = j / RATE
        low += alpha * (rng.uniform(-1.0, 1.0) - low)
        dc += .025 * (low - dc)
        env = smoothstep(t / max(attack, 1 / RATE))
        env *= smoothstep((duration - t) / max(release, 1 / RATE))
        env *= math.exp(-decay * t)
        if flutter:
            env *= .65 + .35 * math.cos(TAU * flutter * t)
        index = start + j
        if 0 <= index < len(dst):
            dst[index] += gain * env * (low - dc)


def click(dst: list[float], at: float, seed: int, gain: float = .4,
          body: float = 170.0) -> None:
    noise(dst, at, .046, gain, seed, cutoff=2300, decay=90,
          attack=.0012, release=.010)
    tone(dst, at, .065, body, gain * .32, end_frequency=body * .65,
         attack=.0015, release=.025, decay=45, harmonic=.18)


def periodic_noise(dst: list[float], gain: float, seed: int,
                   low_hz: float = 140.0, high_hz: float = 1400.0) -> None:
    """Band-limited pseudo static made from periodic, random-phase partials."""
    rng = random.Random(seed)
    duration = len(dst) / RATE
    partials: list[tuple[float, float, float]] = []
    for _ in range(44):
        hz = rng.uniform(low_hz, high_hz)
        hz = round(hz * duration) / duration
        amplitude = gain * rng.uniform(.5, 1.0) / math.sqrt(44)
        partials.append((TAU * hz / RATE, rng.uniform(0.0, TAU), amplitude))
    for omega, phase, amplitude in partials:
        for i in range(len(dst)):
            dst[i] += amplitude * math.sin(omega * i + phase)


def periodic_pad(dst: list[float], frequencies: list[float], gain: float,
                 shimmer: float = .0) -> None:
    duration = len(dst) / RATE
    for note_index, frequency in enumerate(frequencies):
        frequency = round(frequency * duration) / duration
        phase = note_index * .73
        for i in range(len(dst)):
            t = i / RATE
            wow = .0015 * math.sin(TAU * 4 * t / duration)
            carrier = TAU * frequency * t + phase + wow
            value = math.sin(carrier) + .10 * math.sin(carrier * 3.0)
            mod = .84 + .16 * math.sin(TAU * 2 * t / duration + note_index)
            dst[i] += gain * value * mod
            if shimmer:
                dst[i] += shimmer * gain * math.sin(carrier * 2.0)


def cyclic_delay(dst: list[float], seconds: float, gain: float) -> None:
    original = dst[:]
    offset = round(seconds * RATE)
    for i in range(len(dst)):
        dst[i] += original[(i - offset) % len(dst)] * gain


def synth(name: str) -> tuple[list[float], bool, float, float, str]:
    """Return samples, loop flag, peak target, suggested runtime dB, description."""
    seed = zlib.crc32(name.encode())
    if name == "button_press":
        dst = buffer(.105)
        click(dst, 0, seed, .6, 175)
        tone(dst, .010, .055, 420, .055, decay=28)
        return dst, False, -10, -2, "Short damped mechanical switch with a warm relay body"
    if name == "button_release":
        dst = buffer(.075)
        click(dst, 0, seed, .38, 240)
        return dst, False, -13, -2, "Light spring return, higher and softer than button press"
    if name in ["power_on", "power_off"]:
        on = name == "power_on"
        dst = buffer(.52 if on else .37)
        click(dst, 0, seed, .42, 115)
        notes = [(0.025, 261.63), (.14, 392.0), (.26, 523.25)] if on else [(0.015, 392.0), (.11, 261.63), (.20, 130.81)]
        for at, frequency in notes:
            tone(dst, at, .20 if on else .15, frequency, .10,
                 release=.08, decay=6, harmonic=.07)
        return dst, False, -10, -2, "Rising warm three-note power confirmation" if on else "Falling three-note soft power-down"
    if name == "knob_detent":
        dst = buffer(.045)
        noise(dst, 0, .032, .5, seed, cutoff=1700, decay=140, attack=.0007, release=.008)
        tone(dst, 0, .04, 285, .10, end_frequency=150, attack=.0008, decay=95, release=.015)
        return dst, False, -12, -3, "Tiny ceramic detent with a low tactile knock"
    if name == "knob_limit":
        dst = buffer(.13)
        click(dst, 0, seed, .40, 95)
        click(dst, .055, seed + 1, .20, 80)
        return dst, False, -12, -3, "Damped double stop at a rotary end limit"
    if name == "radio_tune":
        dst = buffer(1.2)
        periodic_noise(dst, .075, seed, 200, 1800)
        periodic_pad(dst, [60, 180], .004)
        for i in range(len(dst)):
            t = i / RATE
            dst[i] *= .80 + .20 * math.sin(TAU * 5 * t / 1.2)
        return dst, True, -14, -6, "Soft band-limited receiver static; periodic and seamless"
    if name == "radio_station":
        dst = buffer(8.0)
        periodic_pad(dst, [130.8128, 164.8138, 246.9417], .025, .06)
        melody = [523.251, 659.255, 783.991, 659.255, 587.330, 493.883, 440.0, 391.995,
                  523.251, 659.255, 587.330, 493.883, 440.0, 391.995, 329.628, 391.995]
        for step, frequency in enumerate(melody):
            tone(dst, step * .5, .47, frequency, .105, attack=.016,
                 release=.16, decay=3.5, harmonic=.05, cyclic=True)
        for beat in range(16):
            frequency = [65.406, 65.406, 87.307, 97.999][beat // 4]
            tone(dst, beat * .5, .37, frequency, .05, attack=.02,
                 release=.11, decay=3.0, harmonic=.13, cyclic=True)
        cyclic_delay(dst, .25, .15)
        periodic_noise(dst, .0007, seed, 300, 1700)
        return dst, True, -11, -3, "Original eight-second C-major radio miniature with rounded electric-piano lead"
    if name == "tape_play":
        dst = buffer(8.0)
        periodic_pad(dst, [146.832, 174.614, 220.0, 261.626], .026, .11)
        melody = [440.0, 391.995, 349.228, 329.628, 293.665, 349.228, 329.628, 261.626]
        for step, frequency in enumerate(melody):
            tone(dst, step, .96, frequency, .075, attack=.05,
                 release=.30, decay=1.8, harmonic=.19, cyclic=True)
        periodic_noise(dst, .0011, seed, 350, 1800)
        cyclic_delay(dst, .375, .18)
        return dst, True, -12, -3, "Original slow D-minor magnetic-tape memory, gentle wow and hiss"
    if name in ["tape_rewind", "tape_fast_forward"]:
        fast = name == "tape_fast_forward"
        seconds = 1.0 if fast else 1.2
        dst = buffer(seconds)
        periodic_noise(dst, .016, seed, 500 if fast else 250, 2000 if fast else 1450)
        base = 540 if fast else 320
        for i in range(len(dst)):
            t = i / RATE
            warble = .065 * math.sin(TAU * (17 if fast else 9) * t / seconds)
            hum = math.sin(TAU * round(base * seconds) * t / seconds + warble)
            upper = .13 * math.sin(TAU * round(base * 2.03 * seconds) * t / seconds)
            roll = .6 + .4 * math.cos(TAU * (13 if fast else 7) * t / seconds) ** 6
            dst[i] += .04 * roll * (hum + upper)
        return dst, True, -15, -3, "High-speed capstan and tape flutter" if fast else "Lower rewind motor with periodic tape flutter"
    if name == "tape_stop":
        dst = buffer(.25)
        click(dst, 0, seed, .4, 130)
        tone(dst, .018, .19, 300, .12, end_frequency=55, attack=.005, release=.04, decay=8)
        return dst, False, -11, -2, "Transport latch and short descending motor stop"
    if name == "tape_record":
        dst = buffer(.27)
        click(dst, 0, seed, .45, 145)
        tone(dst, .035, .09, 523.251, .09, attack=.004, release=.045, harmonic=.03)
        tone(dst, .135, .09, 659.255, .075, attack=.004, release=.045, harmonic=.03)
        return dst, False, -11, -2, "Record latch with a quiet two-note arming signal"
    if name == "lamp_switch":
        dst = buffer(.15)
        click(dst, 0, seed, .44, 210)
        tone(dst, .014, .11, 330, .045, end_frequency=395, attack=.008, release=.055, decay=8)
        return dst, False, -11, -2, "Small bakelite lamp switch and a subdued electrical glint"
    if name in ["keyboard_key", "keyboard_space"]:
        space = name == "keyboard_space"
        dst = buffer(.11 if space else .075)
        click(dst, 0, seed, .45, 110 if space else 195)
        noise(dst, .015, .05, .065, seed + 3, cutoff=1300, decay=40)
        return dst, False, -11, -3, "Longer, lower space-bar spring" if space else "Short rounded vintage keyboard switch"
    if name in ["tray_open", "tray_close"]:
        opened = name == "tray_open"
        dst = buffer(.56 if opened else .48)
        noise(dst, .015, .38, .055, seed, cutoff=950, flutter=24, attack=.03, release=.07)
        tone(dst, .015, .40, 180 if opened else 310, .07,
             end_frequency=300 if opened else 140, attack=.045, release=.10, harmonic=.12)
        click(dst, .43 if opened else .36, seed + 1, .25, 125)
        return dst, False, -12, -3, "Short softly whirring tray extension" if opened else "Descending tray servo and seating click"
    if name in ["drawer_open", "drawer_close"]:
        opened = name == "drawer_open"
        seconds = .67 if opened else .60
        dst = buffer(seconds)
        noise(dst, .02, seconds - .12, .12, seed, cutoff=750,
              flutter=19 if opened else 14, attack=.07, release=.09)
        tone(dst, .035, seconds - .15, 82 if opened else 108, .045,
             end_frequency=100 if opened else 75, attack=.06, release=.09, harmonic=.2)
        click(dst, seconds - .09, seed + 1, .22 if opened else .4, 85)
        return dst, False, -12, -3, "Soft wood-and-roller drawer slide with a light open stop" if opened else "Shorter drawer slide and a padded closing stop"
    if name == "paper":
        dst = buffer(.34)
        noise(dst, .005, .19, .16, seed, cutoff=2400, attack=.025, release=.04, flutter=33)
        noise(dst, .11, .21, .11, seed + 1, cutoff=1600, attack=.03, release=.06, flutter=21)
        return dst, False, -13, -3, "Layered dry paper lift and folder rustle"
    if name == "page_turn":
        dst = buffer(.29)
        noise(dst, .003, .24, .17, seed, cutoff=1850, attack=.055, release=.075, flutter=24)
        noise(dst, .19, .075, .10, seed + 4, cutoff=2600, decay=15, attack=.006, release=.025)
        return dst, False, -13, -3, "Single soft page arc ending in a quiet paper flick"
    if name == "confirm":
        dst = buffer(.23)
        tone(dst, 0, .14, 392.0, .12, attack=.005, release=.06, harmonic=.04)
        tone(dst, .085, .14, 523.251, .10, attack=.005, release=.06, harmonic=.04)
        return dst, False, -12, -3, "Quiet ascending confirmation pair"
    if name == "error":
        dst = buffer(.22)
        tone(dst, 0, .10, 196, .13, attack=.004, release=.025, harmonic=.2)
        tone(dst, .115, .10, 164.814, .11, attack=.004, release=.025, harmonic=.2)
        return dst, False, -13, -3, "Low, unobtrusive descending rejection pair"
    raise ValueError(name)


def pcm(samples: list[float], loop: bool, peak_db: float) -> array.array:
    mean = sum(samples) / len(samples)
    samples = [value - mean for value in samples]
    if loop:
        # Preserve the periodic musical buffer; gently bleed tiny residual endpoint
        # quantization differences over the final 4ms rather than snapping it.
        count = min(len(samples), round(.004 * RATE))
        delta = samples[-1] - samples[0]
        for j in range(count):
            samples[-count + j] -= delta * smoothstep(j / max(1, count - 1))
    else:
        fade = round(.0025 * RATE)
        for j in range(fade):
            gain = smoothstep(j / max(1, fade - 1))
            samples[j] *= gain
            samples[-j - 1] *= gain
    peak = max(abs(value) for value in samples)
    scale = 10 ** (peak_db / 20) / max(peak, 1e-10)
    result = array.array("h", (round(max(-1.0, min(1.0, value * scale)) * 32767) for value in samples))
    if loop:
        result[-1] = result[0]
    else:
        result[0] = result[-1] = 0
    return result


def measure(path: Path, loop: bool) -> dict:
    with wave.open(str(path), "rb") as source:
        rate = source.getframerate()
        channels = source.getnchannels()
        width = source.getsampwidth()
        values = array.array("h", source.readframes(source.getnframes()))
    if sys.byteorder != "little":
        values.byteswap()
    numbers = [value / 32768 for value in values]
    peak = max(abs(value) for value in numbers)
    rms = math.sqrt(sum(value * value for value in numbers) / len(numbers))
    report = {
        "duration_s": round(len(values) / rate / channels, 6),
        "sample_rate": rate, "channels": channels, "bits": width * 8,
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-12)), 3),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-12)), 3),
        "dc_offset": round(sum(numbers) / len(numbers), 8),
        "clipping_samples": sum(abs(value) >= 32767 for value in values),
        "first_sample": values[0], "last_sample": values[-1],
        "loop_seam_delta": abs(numbers[-1] - numbers[0]) if loop else None,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
    assert report["clipping_samples"] == 0, path
    assert -45 < report["rms_dbfs"] < -9, path
    assert report["peak_dbfs"] < -6, path
    assert width == 2 and channels == 1 and rate == RATE, path
    if loop:
        assert report["loop_seam_delta"] == 0, path
    else:
        assert values[0] == 0 and values[-1] == 0, path
    return report


NAMES = ["button_press", "button_release", "power_on", "power_off", "knob_detent",
         "knob_limit", "radio_tune", "radio_station", "tape_play", "tape_stop",
         "tape_rewind", "tape_fast_forward", "tape_record", "lamp_switch",
         "keyboard_key", "keyboard_space", "tray_open", "tray_close", "drawer_open",
         "drawer_close", "paper", "page_turn", "confirm", "error"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Audit existing WAVs without rewriting them")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    sounds = {}
    if args.check:
        manifest = json.loads((OUT / "manifest.json").read_text())
        for sound_id, entry in manifest["sounds"].items():
            measured = measure(OUT / entry["file"], entry["loop"])
            assert measured["sha256"] == entry["sha256"], sound_id
            sounds[sound_id] = measured
    else:
        for name in NAMES:
            samples, loop, peak_db, suggested, description = synth(name)
            if loop:
                suggested = -21 if name == "radio_tune" else -15 if name in ["radio_station", "tape_play"] else -17
            else:
                suggested = -8 if name in ["button_press", "power_on", "power_off", "lamp_switch"] else -10
            values = pcm(samples, loop, peak_db)
            if sys.byteorder != "little":
                values.byteswap()
            target = OUT / (name + ".wav")
            with wave.open(str(target), "wb") as wav:
                wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
                wav.writeframes(values.tobytes())
            report = measure(target, loop)
            duration = report["duration_s"]
            entry = {"file": target.name, "loop": loop, "suggested_volume_db": suggested,
                     "description": description, **report,
                     "expect": {"not_silent": True, "no_clipping": True,
                                "min_duration": max(0, duration - .002),
                                "max_duration": duration + .002}}
            if loop:
                entry["expect"]["loopable"] = True
            sounds[name] = entry
        manifest = {"generator": "res://tools/generate_control_audio.py", "version": 1,
                    "sample_rate": RATE, "channels": 1, "bits": 16,
                    "original_composition": True,
                    "mix_note": "Suggested levels include headroom; all assets are original offline synthesis.",
                    "sounds": sounds}
        (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"ok": True, "files": len(sounds),
                      "loops": [name for name, item in sounds.items() if item.get("loop_seam_delta") == 0],
                      "peak_dbfs_range": [min(item["peak_dbfs"] for item in sounds.values()),
                                          max(item["peak_dbfs"] for item in sounds.values())],
                      "rms_dbfs_range": [min(item["rms_dbfs"] for item in sounds.values()),
                                         max(item["rms_dbfs"] for item in sounds.values())],
                      "clipping_samples": sum(item["clipping_samples"] for item in sounds.values())},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
