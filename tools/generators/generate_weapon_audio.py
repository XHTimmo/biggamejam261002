"""Generate deterministic, original PCM weapon effects (no third-party samples)."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 44100
DEST = Path(__file__).resolve().parents[1] / "assets" / "audio" / "weapons"


def render(name, duration, seed, synth):
    rng = random.Random(seed)
    samples = []
    low = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        raw = rng.uniform(-1, 1)
        low = low * 0.82 + raw * 0.18
        value = synth(t, low, raw - low)
        # Smooth edges and leave 3 dB of headroom; mixing gain is set in Godot.
        value *= min(1, t / 0.0015, (duration - t) / 0.012)
        samples.append(value)
    peak = max(abs(v) for v in samples)
    scale = 0.70 / max(peak, 0.001)
    pcm = b"".join(struct.pack("<h", round(v * scale * 32767)) for v in samples)
    with wave.open(str(DEST / (name + ".wav")), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(pcm)


def clack(t, start, low, sharp, weight=1.0, pitch=220):
    age = t - start
    if age < 0 or age > 0.12:
        return 0.0
    envelope = math.exp(-age / 0.016) * min(1, age / 0.001)
    resonance = math.sin(math.tau * pitch * age) + 0.3 * math.sin(math.tau * 1370 * age)
    return weight * (sharp * 0.48 + low * 0.9 + resonance * 0.22) * envelope


def shot(element, charged):
    stretch = 1.5 if charged else 1.0

    def synth(t, low, sharp):
        age = t / stretch
        if element in ("hydrogen", "oxygen"):
            pitch = 240 if element == "hydrogen" else 150
            hiss = sharp * (0.42 if element == "hydrogen" else 0.32) * math.exp(-age / 0.043)
            body = (low * 1.1 + 0.17 * math.sin(math.tau * pitch * age)) * math.exp(-age / 0.021)
            return hiss + body
        if element == "carbon":
            puff = low * 1.8 * math.exp(-age / 0.025)
            grains = sum(clack(age, start, low, sharp, 0.36, 740) for start in (0, 0.017, 0.037, 0.063))
            return puff + grains
        metal = (math.sin(math.tau * 270 * age) + 0.38 * math.sin(math.tau * 1730 * age)
                 + 0.18 * math.sin(math.tau * 3110 * age)) * 0.22 * math.exp(-age / 0.038)
        return low * 1.9 * math.exp(-age / 0.019) + sharp * 0.45 * math.exp(-age / 0.009) + metal

    return synth


def reload_sound(gas, complete=False):
    starts = (0, 0.045) if complete else ((0, 0.08, 0.30, 0.57, 0.89, 1.04) if gas else (0, 0.07, 0.24, 0.42, 0.61, 0.70))

    def synth(t, low, sharp):
        clicks = sum(clack(t, start, low, sharp, 0.85 if i == 0 else 0.55,
                           300 if gas else 175) for i, start in enumerate(starts))
        # Gas bottle seats with a quiet pressure hiss; solid magazines use a dry ratchet.
        air = sharp * 0.06 * math.sin(math.pi * (t - 0.1) / 0.5) if gas and not complete and 0.1 < t < 0.6 else 0
        return clicks + air

    return synth


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for index, element in enumerate(("hydrogen", "oxygen", "carbon", "iron")):
        for charged in (False, True):
            duration = (0.17, 0.22, 0.16, 0.24)[index] * (1.5 if charged else 1)
            render(element + ("_charged" if charged else "_normal"), duration,
                   410 + index * 2 + int(charged), shot(element, charged))
    for gas in (True, False):
        family = "gas" if gas else "solid"
        render(family + "_reload", 1.2 if gas else 0.8, 500 + int(gas), reload_sound(gas))
        render(family + "_reload_complete", 0.19, 510 + int(gas), reload_sound(gas, True))
    print("Generated 12 original weapon WAV effects in", DEST)


if __name__ == "__main__":
    main()
