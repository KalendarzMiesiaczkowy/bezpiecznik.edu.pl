"""Generates app/assets/audio/sos.wav: piercing 2.9 kHz Morse SOS (unit 200 ms,
7-unit tail so a loop keeps the rhythm). Stdlib only. Run from repo root."""
import math, struct, wave

RATE, UNIT, FREQ = 44100, 0.2, 2900
SOS = [1, 1, 1, 3, 3, 3, 1, 1, 1]  # dot=1 unit, dash=3 units

def tone(sec):
    n = int(RATE * sec)
    ramp = int(RATE * 0.005)  # 5 ms fade avoids clicks
    out = []
    for i in range(n):
        env = min(1.0, i / ramp, (n - 1 - i) / ramp)
        v = 0.95 * env * (math.sin(2 * math.pi * FREQ * i / RATE) + 0.3 * math.sin(2 * math.pi * 2 * FREQ * i / RATE)) / 1.3
        out.append(int(v * 32767))
    return out

def silence(units):
    return [0] * int(RATE * UNIT * units)

samples = []
for k, units in enumerate(SOS):
    samples += tone(units * UNIT)
    gap = 3 if k in (2, 5) else 7 if k == 8 else 1
    samples += silence(gap)

with wave.open("app/assets/audio/sos.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
