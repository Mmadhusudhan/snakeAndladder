#!/usr/bin/env python3
"""Generates the game's sound effects and music loop as 16-bit mono WAVs.

Everything is synthesised here, so the assets are original and licence-free.
Run from the repo root:  python3 tool/gen_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
random.seed(42)


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak if peak > 0.9 else 1.0
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(f"wrote {name} ({len(samples) / RATE:.2f}s)")


def silence(sec):
    return [0.0] * int(sec * RATE)


def tone(freq, sec, vol=0.5, attack=0.005, decay=None, shape="sine", harmonics=(1.0,)):
    n = int(sec * RATE)
    decay = sec if decay is None else decay
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-3.0 * t / decay)
        v = 0.0
        for k, amp in enumerate(harmonics, start=1):
            ph = 2 * math.pi * freq * k * t
            if shape == "square":
                v += amp * (1 if math.sin(ph) >= 0 else -1)
            elif shape == "tri":
                v += amp * (2 / math.pi) * math.asin(math.sin(ph))
            else:
                v += amp * math.sin(ph)
        out.append(vol * env * v / sum(harmonics))
    return out


def noise(sec, vol=0.5, lowpass=1, env_fn=None):
    n = int(sec * RATE)
    out = []
    acc = 0.0
    for i in range(n):
        t = i / RATE
        white = random.uniform(-1, 1)
        acc += (white - acc) / lowpass  # crude low-pass
        env = env_fn(t) if env_fn else math.exp(-4 * t / sec)
        out.append(vol * env * acc)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for tr in tracks:
        for i, s in enumerate(tr):
            out[i] += s
    return out


def place(base, clip, at):
    start = int(at * RATE)
    if len(base) < start + len(clip):
        base.extend([0.0] * (start + len(clip) - len(base)))
    for i, s in enumerate(clip):
        base[start + i] += s
    return base


# --- sound effects ----------------------------------------------------------

# Dice: a rattle of short clicks that slows down, then a landing knock.
dice = silence(1.0)
t = 0.0
gap = 0.04
while t < 0.72:
    click = noise(0.03, vol=random.uniform(0.3, 0.6), lowpass=3)
    place(dice, click, t)
    place(dice, tone(random.choice([1800, 2200, 2600]), 0.03, vol=0.15), t)
    t += gap
    gap *= 1.12
place(dice, mix(noise(0.08, 0.6, 6), tone(160, 0.12, 0.5, harmonics=(1, 0.4))), 0.78)
write("dice.wav", dice)

# Step: a soft wooden tick.
write("step.wav", mix(tone(900, 0.07, 0.5, decay=0.05), noise(0.02, 0.25, 4)))

# Ladder: climbing arpeggio.
lad = silence(0.7)
for i, f in enumerate([523, 659, 784, 1047, 1319]):
    place(lad, tone(f, 0.22, 0.45, shape="tri", harmonics=(1, 0.3)), i * 0.11)
write("ladder.wav", lad)

# Snake: a hiss that swells, then a bite thump.
hiss = noise(0.9, 0.7, lowpass=2, env_fn=lambda t: math.sin(math.pi * min(1, t / 0.9)) ** 1.5)
bite = place(silence(0.95), mix(tone(90, 0.25, 0.8, harmonics=(1, 0.5, 0.25)), noise(0.05, 0.5, 5)), 0.62)
write("snake.wav", mix(hiss, bite))

# Win: a short fanfare.
win = silence(1.8)
for i, f in enumerate([523, 659, 784, 1047]):
    place(win, tone(f, 0.35, 0.5, shape="square", harmonics=(1, 0.5, 0.25)), i * 0.14)
place(win, tone(1319, 1.0, 0.55, shape="square", harmonics=(1, 0.4, 0.2)), 0.6)
place(win, tone(784, 1.0, 0.35, shape="tri"), 0.6)
place(win, tone(523, 1.0, 0.3, shape="tri"), 0.6)
write("win.wav", win)

# Six / extra turn: bright two-note chime.
write("six.wav", mix(place(silence(0.5), tone(1047, 0.3, 0.5), 0.0), place(silence(0.5), tone(1568, 0.4, 0.5), 0.12)))

# Blocked / forfeit: a dull thud.
write("blocked.wav", mix(tone(140, 0.3, 0.7, harmonics=(1, 0.5)), noise(0.06, 0.3, 6)))

# Click: UI tap.
write("click.wav", mix(tone(1400, 0.04, 0.5, decay=0.03), noise(0.012, 0.2, 2)))

# Turn: soft notification when it becomes your turn.
write("turn.wav", mix(place(silence(0.45), tone(880, 0.25, 0.4, shape="tri"), 0.0), place(silence(0.45), tone(1175, 0.3, 0.4, shape="tri"), 0.1)))

# --- music loop ---------------------------------------------------------------
# A relaxed 8-bar jungle groove at 96 BPM: bass, marimba-ish arpeggio, shaker.
BPM = 96
beat = 60 / BPM
bars = 8
total = bars * 4 * beat
music = silence(total)
chords = [(55, [220, 262, 330]), (65, [262, 330, 392]), (49, [196, 247, 294]), (62, [247, 294, 370])]  # A-, C, G, B-
for bar in range(bars):
    bass_f, arp = chords[bar % 4]
    bar_t = bar * 4 * beat
    for b in range(4):
        place(music, tone(bass_f, beat * 0.9, 0.45, shape="tri", harmonics=(1, 0.3)), bar_t + b * beat)
        for s in range(2):
            place(music, noise(0.05, 0.12, 2), bar_t + b * beat + s * beat / 2)
    for i in range(8):
        f = arp[i % 3] * (2 if i % 4 == 3 else 1)
        place(music, tone(f, beat * 0.45, 0.22, shape="sine", harmonics=(1, 0.2)), bar_t + i * beat / 2)
    if bar % 2 == 1:
        place(music, tone(arp[2] * 2, beat * 1.5, 0.18, shape="tri"), bar_t + 2 * beat)
# Trim to an exact loop length so it repeats seamlessly.
music = music[: int(total * RATE)]
write("music.wav", music)
