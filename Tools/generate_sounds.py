#!/usr/bin/env python3
"""Rebuild TUPPEN's original mono PCM effects using only the Python standard library."""

import math
from pathlib import Path
import random
import struct
import wave


SAMPLE_RATE = 44_100
DESTINATION = Path(__file__).resolve().parents[1] / "Tuppen/Resources/Sounds"


def paper(duration, seed, body, tail):
    """A filtered noise brush with a short, dull contact transient."""
    source = random.Random(seed)
    previous = 0.0
    low = 0.0
    samples = []
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        noise = source.uniform(-1, 1)
        low += 0.24 * (noise - low)
        brush = (low - previous * 0.65) * math.exp(-time / tail)
        previous = low
        contact = math.sin(2 * math.pi * body * time) * math.exp(-time / 0.014)
        samples.append(brush * 0.78 + contact * 0.16)
    return samples


def wood(duration=0.125):
    """Damped, inharmonic resonances keep the tap dry rather than pitched."""
    source = random.Random(701)
    samples = []
    previous = 0.0
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        impulse = source.uniform(-1, 1)
        previous += 0.38 * (impulse - previous)
        contact = previous * math.exp(-time / 0.004) * 0.36
        body = sum(
            weight * math.sin(2 * math.pi * frequency * time) * math.exp(-time / decay)
            for frequency, weight, decay in [(438, 0.50, 0.022), (731, 0.28, 0.014), (1267, 0.12, 0.009)]
        )
        samples.append(contact + body)
    return samples


def result():
    """A soft pair of settled card contacts, deliberately without a victory chime."""
    samples = [0.0] * round(0.32 * SAMPLE_RATE)
    for offset, scale, seed in [(0, 0.85, 109), (0.105, 0.58, 113)]:
        start = round(offset * SAMPLE_RATE)
        for index, sample in enumerate(paper(0.18, seed, 178, 0.045)):
            samples[start + index] += sample * scale
    return samples


def write(name, samples, peak):
    # Remove DC, then apply short endpoint fades to avoid digital clicks. Peak
    # levels remain well below full scale; playback applies a further gain cut.
    mean = sum(samples) / len(samples)
    samples = [value - mean for value in samples]
    for index in range(len(samples)):
        attack = min(1.0, index / (SAMPLE_RATE * 0.0007))
        release = min(1.0, (len(samples) - 1 - index) / (SAMPLE_RATE * 0.012))
        samples[index] *= attack * release
    gain = peak / max(abs(sample) for sample in samples)
    pcm = b"".join(struct.pack("<h", round(sample * gain * 32767)) for sample in samples)
    with wave.open(str(DESTINATION / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    write("card-dealt", paper(0.12, 11, 218, 0.026), 0.22)
    write("card-placed", paper(0.16, 17, 186, 0.035), 0.28)
    write("table-knock", wood(), 0.34)
    write("trick-collected", paper(0.23, 23, 154, 0.070), 0.23)
    write("stroke-added", paper(0.10, 29, 292, 0.019), 0.24)
    write("match-result", result(), 0.26)


if __name__ == "__main__":
    main()
