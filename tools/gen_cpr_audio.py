"""Generates the CPR metronome sounds with the standard library only.

Run: python3 -I tools/gen_cpr_audio.py  (writes into app/assets/audio/)
Outputs (16-bit mono, 44.1 kHz):
  cpr_click.wav   short compression click (1.2 kHz, 30 ms, fast decay)
  cpr_breath.wav  two-tone cue marking the breath phase (~0.5 s)
"""
import math
import struct
import wave
import os

# Output: app/assets/audio/ (run from anywhere: python3 -I tools/gen_cpr_audio.py).
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "app", "assets", "audio")

RATE = 44100


def tone(freq, ms, decay_ms, peak):
    n = int(RATE * ms / 1000)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * 1000 / decay_ms)
        # 2 ms linear attack avoids a pop at the start.
        env *= min(1.0, i / (RATE * 0.002))
        out.append(peak * env * math.sin(2 * math.pi * freq * t))
    return out


def write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


write(os.path.join(OUT, "cpr_click.wav"), tone(1200, 30, 8, 0.9))
silence = [0.0] * int(RATE * 0.05)
write(os.path.join(OUT, "cpr_breath.wav"), tone(660, 200, 120, 0.8) + silence + tone(880, 200, 120, 0.8))
