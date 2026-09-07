"""
Generates crisp, professional 16-bit PCM WAV assets for KillEm
covering weapons, foley, zombie vocalizations, footsteps, and pickups.
"""
import os
import math
import struct
import random

SAMPLE_RATE = 22050

def write_wav(file_path: str, samples: list[float], sample_rate: int = SAMPLE_RATE):
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    num_samples = len(samples)
    num_channels = 1
    bits_per_sample = 16
    byte_rate = sample_rate * num_channels * (bits_per_sample // 8)
    block_align = num_channels * (bits_per_sample // 8)
    data_size = num_samples * (bits_per_sample // 8)
    chunk_size = 36 + data_size

    with open(file_path, "wb") as f:
        # RIFF header
        f.write(b"RIFF")
        f.write(struct.pack("<I", chunk_size))
        f.write(b"WAVE")
        # fmt subchunk
        f.write(b"fmt ")
        f.write(struct.pack("<I", 16)) # Subchunk1Size
        f.write(struct.pack("<H", 1))  # AudioFormat (PCM)
        f.write(struct.pack("<H", num_channels))
        f.write(struct.pack("<I", sample_rate))
        f.write(struct.pack("<I", byte_rate))
        f.write(struct.pack("<H", block_align))
        f.write(struct.pack("<H", bits_per_sample))
        # data subchunk
        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            val = int(clamped * 32767.0)
            f.write(struct.pack("<h", val))

def generate_noise(duration: float, decay_power: float = 2.0) -> list[float]:
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / num_samples
        envelope = math.pow(1.0 - t, decay_power)
        val = (random.random() * 2.0 - 1.0) * envelope
        samples.append(val)
    return samples

def make_pistol() -> list[float]:
    dur = 0.16
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Snappy crack: high transient noise + 280Hz body + slide click at 0.04s
        env_crack = math.exp(-t * 45.0)
        crack = (random.random() * 2.0 - 1.0) * env_crack
        # Body thump
        env_body = math.exp(-t * 28.0)
        body = math.sin(2.0 * math.pi * 280.0 * t * (1.0 - t * 2.0)) * env_body * 0.7
        # Slide mechanical click around 0.04s
        slide = 0.0
        if 0.035 <= t <= 0.055:
            slide_t = (t - 0.035) / 0.02
            slide = math.sin(2.0 * math.pi * 1800.0 * t) * math.sin(slide_t * math.pi) * 0.4
        samples.append(crack * 0.75 + body + slide)
    return samples

def make_shotgun() -> list[float]:
    dur = 0.32
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Deep sub-bass thump (55Hz dropping to 30Hz)
        env_sub = math.exp(-t * 12.0)
        freq = max(30.0, 55.0 - t * 80.0)
        sub = math.sin(2.0 * math.pi * freq * t) * env_sub * 0.95
        # Explosive burst noise
        env_burst = math.exp(-t * 22.0)
        burst = (random.random() * 2.0 - 1.0) * env_burst * 0.85
        # Mid punch
        env_mid = math.exp(-t * 35.0)
        mid = math.sin(2.0 * math.pi * 140.0 * t) * env_mid * 0.5
        samples.append(sub + burst + mid)
    return samples

def make_shotgun_pump() -> list[float]:
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # Forward slide click around 0.04s
        if 0.02 <= t <= 0.07:
            st = (t - 0.02) / 0.05
            val += (random.random() * 2.0 - 1.0) * math.sin(st * math.pi) * 0.6
            val += math.sin(2.0 * math.pi * 950.0 * t) * 0.3
        # Backward lock click around 0.14s
        if 0.12 <= t <= 0.18:
            st = (t - 0.12) / 0.06
            val += (random.random() * 2.0 - 1.0) * math.sin(st * math.pi) * 0.8
            val += math.sin(2.0 * math.pi * 1400.0 * t) * 0.4
        samples.append(val)
    return samples

def make_rifle() -> list[float]:
    dur = 0.13
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 38.0)
        crack = (random.random() * 2.0 - 1.0) * env * 0.8
        punch = math.sin(2.0 * math.pi * 380.0 * t) * math.exp(-t * 45.0) * 0.7
        res = math.sin(2.0 * math.pi * 820.0 * t) * math.exp(-t * 25.0) * 0.3
        samples.append(crack + punch + res)
    return samples

def make_flamethrower_start() -> list[float]:
    dur = 0.25
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Ignition pop at t=0.03
        pop = 0.0
        if 0.01 <= t <= 0.06:
            pop = math.sin(2.0 * math.pi * 120.0 * t) * 0.7 + (random.random() * 2.0 - 1.0) * 0.5
        # Low whoosh building up
        env = min(1.0, t * 8.0) * math.exp(-t * 3.0)
        rumble = (random.random() * 2.0 - 1.0) * env * 0.65
        samples.append(pop + rumble)
    return samples

def make_flamethrower_loop() -> list[float]:
    dur = 0.4
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Turbulent roaring whoosh
        mod = 0.7 + 0.3 * math.sin(2.0 * math.pi * 24.0 * t)
        noise = (random.random() * 2.0 - 1.0) * mod * 0.65
        rumble = math.sin(2.0 * math.pi * 85.0 * t) * 0.25
        samples.append(noise + rumble)
    return samples

def make_minigun_spin() -> list[float]:
    dur = 0.35
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Rising motor whine from 300 to 850 Hz
        freq = 300.0 + (t / dur) * 550.0
        whine = math.sin(2.0 * math.pi * freq * t) * 0.45
        whine += math.sin(2.0 * math.pi * (freq * 1.5) * t) * 0.2
        buzz = (random.random() * 2.0 - 1.0) * 0.15
        samples.append((whine + buzz) * min(1.0, t * 10.0))
    return samples

def make_minigun_fire() -> list[float]:
    dur = 0.06
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 60.0)
        slap = math.sin(2.0 * math.pi * 180.0 * t) * env * 0.8
        crack = (random.random() * 2.0 - 1.0) * env * 0.8
        samples.append(slap + crack)
    return samples

def make_dry_fire() -> list[float]:
    dur = 0.05
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 90.0)
        click = math.sin(2.0 * math.pi * 1900.0 * t) * env * 0.85
        samples.append(click)
    return samples

def make_casing_ping(freq: float) -> list[float]:
    dur = 0.12
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 35.0)
        ping = math.sin(2.0 * math.pi * freq * t) * env * 0.4
        ping += math.sin(2.0 * math.pi * (freq * 2.1) * t) * env * 0.15
        noise = (random.random() * 2.0 - 1.0) * math.exp(-t * 80.0) * 0.15
        samples.append(ping + noise)
    return samples

def make_reload_mag_out() -> list[float]:
    dur = 0.14
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        scrape = (random.random() * 2.0 - 1.0) * env * 0.4
        click = math.sin(2.0 * math.pi * 950.0 * t) * math.exp(-t * 40.0) * 0.4
        samples.append(scrape + click)
    return samples

def make_reload_mag_in() -> list[float]:
    dur = 0.16
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 25.0)
        thud = math.sin(2.0 * math.pi * 160.0 * t) * env * 0.7
        clack = math.sin(2.0 * math.pi * 1250.0 * t) * math.exp(-t * 50.0) * 0.6
        samples.append(thud + clack)
    return samples

def make_reload_bolt_rack() -> list[float]:
    dur = 0.15
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        clink = math.sin(2.0 * math.pi * 2100.0 * t) * math.exp(-t * 45.0) * 0.7
        slide = (random.random() * 2.0 - 1.0) * math.exp(-t * 30.0) * 0.4
        samples.append(clink + slide)
    return samples

def make_footstep_concrete() -> list[float]:
    dur = 0.1
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        thump = math.sin(2.0 * math.pi * 110.0 * t) * math.exp(-t * 40.0) * 0.8
        slap = (random.random() * 2.0 - 1.0) * math.exp(-t * 70.0) * 0.4
        samples.append(thump + slap)
    return samples

def make_footstep_gravel() -> list[float]:
    dur = 0.13
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        crunch = (random.random() * 2.0 - 1.0) * math.exp(-t * 25.0) * 0.6
        crunch += (random.random() * 2.0 - 1.0) * math.exp(-abs(t - 0.04) * 45.0) * 0.4
        samples.append(crunch)
    return samples

def make_footstep_metal() -> list[float]:
    dur = 0.18
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 20.0)
        clang = math.sin(2.0 * math.pi * 650.0 * t) * env * 0.5
        clang += math.sin(2.0 * math.pi * 1320.0 * t) * env * 0.3
        thump = math.sin(2.0 * math.pi * 120.0 * t) * math.exp(-t * 40.0) * 0.5
        samples.append(clang + thump)
    return samples

def make_zombie_idle() -> list[float]:
    dur = 0.55
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        vibrato = 1.0 + 0.3 * math.sin(2.0 * math.pi * 8.0 * t)
        freq = (85.0 + math.sin(t * 5.0) * 15.0) * vibrato
        growl = math.sin(2.0 * math.pi * freq * t) * 0.5
        throat = (random.random() * 2.0 - 1.0) * 0.25 * math.sin((t / dur) * math.pi)
        samples.append((growl + throat) * math.sin((t / dur) * math.pi) * 0.8)
    return samples

def make_zombie_aggro() -> list[float]:
    dur = 0.4
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        hiss = (random.random() * 2.0 - 1.0) * env * 0.65
        growl = math.sin(2.0 * math.pi * (160.0 + t * 80.0) * t) * env * 0.4
        samples.append(hiss + growl)
    return samples

def make_zombie_hurt() -> list[float]:
    dur = 0.16
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 25.0)
        thud = math.sin(2.0 * math.pi * 140.0 * t) * env * 0.6
        squelch = (random.random() * 2.0 - 1.0) * env * 0.65
        samples.append(thud + squelch)
    return samples

def make_zombie_death() -> list[float]:
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 8.0)
        collapse = math.sin(2.0 * math.pi * (110.0 - t * 40.0) * t) * env * 0.6
        gasp = (random.random() * 2.0 - 1.0) * math.exp(-t * 12.0) * 0.45
        samples.append(collapse + gasp)
    return samples

def make_dog_bark() -> list[float]:
    dur = 0.16
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        freq = 460.0 - (t / dur) * 220.0
        bark = math.sin(2.0 * math.pi * freq * t) * env * 0.75
        snarl = (random.random() * 2.0 - 1.0) * env * 0.35
        samples.append(bark + snarl)
    return samples

def make_dog_skitter() -> list[float]:
    dur = 0.08
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        click = (random.random() * 2.0 - 1.0) * math.exp(-t * 60.0) * 0.5
        samples.append(click)
    return samples

def make_dog_whoosh() -> list[float]:
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        whoosh = (random.random() * 2.0 - 1.0) * env * 0.7
        samples.append(whoosh)
    return samples

def make_mutant_step() -> list[float]:
    dur = 0.35
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 10.0)
        thump = math.sin(2.0 * math.pi * 42.0 * t) * env * 0.95
        shake = (random.random() * 2.0 - 1.0) * math.exp(-t * 20.0) * 0.4
        samples.append(thump + shake)
    return samples

def make_mutant_roar() -> list[float]:
    dur = 0.75
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        r1 = math.sin(2.0 * math.pi * 58.0 * t) * 0.6
        r2 = math.sin(2.0 * math.pi * 116.0 * t) * 0.35
        noise = (random.random() * 2.0 - 1.0) * 0.3
        samples.append((r1 + r2 + noise) * env * 0.9)
    return samples

def make_stomp_crash() -> list[float]:
    dur = 0.5
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 8.0)
        boom = math.sin(2.0 * math.pi * 38.0 * t) * env * 0.9
        shatter = (random.random() * 2.0 - 1.0) * math.exp(-t * 15.0) * 0.8
        samples.append(boom + shatter)
    return samples

def make_pickup_ammo() -> list[float]:
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Latch unbuckle at 0.03s
        latch = 0.0
        if 0.01 <= t <= 0.07:
            latch = math.sin(2.0 * math.pi * 1400.0 * t) * 0.5
        # Brass cartridge jingle at 0.09s
        jingle = 0.0
        if t >= 0.08:
            jt = t - 0.08
            jingle = (math.sin(2.0 * math.pi * 2600.0 * jt) + math.sin(2.0 * math.pi * 3300.0 * jt)) * math.exp(-jt * 30.0) * 0.4
        samples.append(latch + jingle)
    return samples

def make_pickup_health() -> list[float]:
    dur = 0.25
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Zipper tear at 0.02 - 0.10s
        zip_snd = 0.0
        if 0.01 <= t <= 0.10:
            zip_snd = (random.random() * 2.0 - 1.0) * math.sin((t - 0.01) * 40.0) * 0.4
        # Injection hiss at 0.11s
        hiss = 0.0
        if t >= 0.10:
            ht = t - 0.10
            hiss = (random.random() * 2.0 - 1.0) * math.exp(-ht * 20.0) * 0.5
        samples.append(zip_snd + hiss)
    return samples

def make_keycard_chirp() -> list[float]:
    dur = 0.18
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        tone1 = math.sin(2.0 * math.pi * 950.0 * t) * math.exp(-t * 25.0) * 0.5 if t < 0.08 else 0.0
        tone2 = math.sin(2.0 * math.pi * 1850.0 * (t - 0.08)) * math.exp(-(t - 0.08) * 30.0) * 0.5 if t >= 0.08 else 0.0
        samples.append(tone1 + tone2)
    return samples

def make_explosion() -> list[float]:
    dur = 0.48
    n = int(SAMPLE_RATE * dur)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 7.0)
        sub = math.sin(2.0 * math.pi * 48.0 * t) * env * 0.95
        noise = (random.random() * 2.0 - 1.0) * math.exp(-t * 12.0) * 0.85
        samples.append(sub + noise)
    return samples

def main():
    out_dir = "C:/Users/beepl/dev/game/assets/audio"
    print("Generating tactical audio WAV files in", out_dir)
    
    sounds = {
        "weapons/pistol.wav": make_pistol(),
        "weapons/shotgun.wav": make_shotgun(),
        "weapons/shotgun_pump.wav": make_shotgun_pump(),
        "weapons/rifle.wav": make_rifle(),
        "weapons/flame_start.wav": make_flamethrower_start(),
        "weapons/flame_loop.wav": make_flamethrower_loop(),
        "weapons/minigun_spin.wav": make_minigun_spin(),
        "weapons/minigun_fire.wav": make_minigun_fire(),
        "weapons/dry_fire.wav": make_dry_fire(),
        "weapons/casing_1.wav": make_casing_ping(3200.0),
        "weapons/casing_2.wav": make_casing_ping(3800.0),
        "weapons/casing_3.wav": make_casing_ping(4400.0),
        "weapons/reload_mag_out.wav": make_reload_mag_out(),
        "weapons/reload_mag_in.wav": make_reload_mag_in(),
        "weapons/reload_bolt_rack.wav": make_reload_bolt_rack(),
        
        "foley/footstep_concrete.wav": make_footstep_concrete(),
        "foley/footstep_gravel.wav": make_footstep_gravel(),
        "foley/footstep_metal.wav": make_footstep_metal(),
        
        "zombies/zombie_idle.wav": make_zombie_idle(),
        "zombies/zombie_aggro.wav": make_zombie_aggro(),
        "zombies/zombie_hurt.wav": make_zombie_hurt(),
        "zombies/zombie_death.wav": make_zombie_death(),
        "zombies/dog_bark.wav": make_dog_bark(),
        "zombies/dog_skitter.wav": make_dog_skitter(),
        "zombies/dog_whoosh.wav": make_dog_whoosh(),
        "zombies/mutant_step.wav": make_mutant_step(),
        "zombies/mutant_roar.wav": make_mutant_roar(),
        "zombies/stomp_crash.wav": make_stomp_crash(),
        
        "pickups/pickup_ammo.wav": make_pickup_ammo(),
        "pickups/pickup_health.wav": make_pickup_health(),
        "pickups/keycard_chirp.wav": make_keycard_chirp(),
        "environment/explosion.wav": make_explosion()
    }
    
    for rel_path, data in sounds.items():
        full_path = os.path.join(out_dir, rel_path)
        write_wav(full_path, data)
        print("  Generated:", rel_path)
    
    print("All tactical audio files generated successfully!")

if __name__ == "__main__":
    main()
