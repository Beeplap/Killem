"""
High-Fidelity Tactical Audio Generator & Foley Pack Extractor for Outbreak Zombie Shooter
Eliminates all cartoon/8-bit synthesizer artifacts.
Generates cinema-grade 16-bit 44.1kHz PCM WAV assets using physical acoustic models
and extracts authentic CC0 recorded foley from Kenney.nl.
"""
import os
import math
import random
import struct
import io
import zipfile
import urllib.request

SAMPLE_RATE = 44100

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
        f.write(struct.pack("<I", 16))
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

# --- DSP FILTER HELPERS ---
def create_lowpass_filter(cutoff_hz, sample_rate=SAMPLE_RATE):
    rc = 1.0 / (2.0 * math.pi * max(10.0, cutoff_hz))
    dt = 1.0 / sample_rate
    alpha = dt / (rc + dt)
    state = 0.0
    def filter_sample(s):
        nonlocal state
        state += alpha * (s - state)
        return state
    return filter_sample

def create_bandpass_filter(center_hz, bandwidth_hz, sample_rate=SAMPLE_RATE):
    w0 = 2.0 * math.pi * center_hz / sample_rate
    q = max(0.2, center_hz / max(1.0, bandwidth_hz))
    alpha = math.sin(w0) / (2.0 * q)
    b0 = alpha
    b1 = 0.0
    b2 = -alpha
    a0 = 1.0 + alpha
    a1 = -2.0 * math.cos(w0)
    a2 = 1.0 - alpha
    x1 = x2 = y1 = y2 = 0.0
    def filter_sample(x):
        nonlocal x1, x2, y1, y2
        y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x
        y2, y1 = y1, y
        return y
    return filter_sample

def create_brownian_noise(n_samples):
    samples = []
    val = 0.0
    for _ in range(n_samples):
        val += (random.random() * 2.0 - 1.0) * 0.1
        val *= 0.985 # prevent drift
        samples.append(val)
    return samples

# --- WEAPON ACOUSTIC MODELS ---

def make_tactical_pistol() -> list[float]:
    """Realistic 9mm combat pistol: high-pressure supersonic crack + concussive barrel blast."""
    dur = 0.22
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_concussion = create_lowpass_filter(140.0)
    bp_crack = create_bandpass_filter(1100.0, 900.0)
    
    brownian = create_brownian_noise(n)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        
        # 1. Supersonic initial shockwave (0 - 3ms)
        shock = 0.0
        if t < 0.003:
            st = t / 0.003
            shock = (1.0 - st * 1.6) if st < 0.6 else -0.4 * (1.0 - st)
            shock *= 1.3
        
        # 2. Concussive low-end blast (heavy compressed brownian noise)
        env_thump = math.exp(-t * 26.0)
        thump = lp_concussion(brownian[i]) * env_thump * 4.5
        thump = math.tanh(thump * 2.2) # Non-linear barrel distortion
        
        # 3. High-velocity barrel crack
        env_crack = math.exp(-t * 42.0)
        white = (random.random() * 2.0 - 1.0)
        crack = bp_crack(white) * env_crack * 1.2
        
        # 4. Tail reflection (air absorption rolls off highs)
        tail_cutoff = max(180.0, 2400.0 * math.exp(-t * 16.0))
        lp_tail = create_lowpass_filter(tail_cutoff)
        tail = lp_tail(white) * math.exp(-t * 14.0) * 0.4
        
        sig = shock + thump * 0.8 + crack * 0.7 + tail * 0.35
        samples.append(math.tanh(sig * 1.1) * 0.92)
        
    return samples

def make_tactical_shotgun() -> list[float]:
    """12-Gauge Tactical Shotgun: thunderous sub-bass thump + explosive wideband wallop."""
    dur = 0.48
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_sub = create_lowpass_filter(75.0)
    bp_mid = create_bandpass_filter(600.0, 500.0)
    brownian = create_brownian_noise(n)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        
        # 1. Initial shockwave
        shock = 0.0
        if t < 0.005:
            st = t / 0.005
            shock = (1.0 - st * 1.5) * 1.5
        
        # 2. Sub-bass seismic displacement (punch you in the stomach)
        env_sub = math.exp(-t * 14.0)
        sub_raw = lp_sub(brownian[i]) * 8.0 * env_sub
        sub = math.tanh(sub_raw) * 1.2
        
        # 3. Massive spreading pellet burst
        env_burst = math.exp(-t * 22.0)
        white = (random.random() * 2.0 - 1.0)
        mid = bp_mid(white) * env_burst * 1.5
        mid = math.tanh(mid * 1.8)
        
        # 4. Heavy dissipative smoke tail
        env_tail = math.exp(-t * 8.0)
        tail = create_lowpass_filter(max(120.0, 1800.0 * math.exp(-t * 10.0)))(white) * env_tail * 0.5
        
        sig = shock * 0.8 + sub * 0.95 + mid * 0.85 + tail * 0.4
        samples.append(math.tanh(sig) * 0.95)
        
    return samples

def make_tactical_shotgun_pump() -> list[float]:
    """Tactical mechanical pump action: metal slide friction and heavy chamber lock."""
    dur = 0.28
    n = int(SAMPLE_RATE * dur)
    samples = []
    bp_slide = create_bandpass_filter(1400.0, 800.0)
    bp_lock = create_bandpass_filter(800.0, 400.0)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        sig = 0.0
        white = (random.random() * 2.0 - 1.0)
        
        # Slide back (t: 0.02 - 0.08)
        if 0.02 <= t <= 0.09:
            st = (t - 0.02) / 0.07
            env = math.sin(st * math.pi)
            sig += bp_slide(white) * env * 0.6
        
        # Chamber lock (t: 0.16 - 0.24)
        if 0.15 <= t <= 0.25:
            lt = (t - 0.15) / 0.10
            env = math.exp(-lt * 25.0)
            click = bp_lock(white) * env * 1.1
            thud = create_lowpass_filter(220.0)(white) * env * 0.7
            sig += click + thud
            
        samples.append(math.tanh(sig) * 0.8)
    return samples

def make_tactical_rifle() -> list[float]:
    """5.56mm Military Carbine: razor-sharp supersonic snap + tight chamber impulse."""
    dur = 0.18
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_punch = create_lowpass_filter(220.0)
    bp_crack = create_bandpass_filter(1600.0, 1100.0)
    brownian = create_brownian_noise(n)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        white = (random.random() * 2.0 - 1.0)
        
        # Needle-sharp supersonic crack
        shock = 0.0
        if t < 0.002:
            st = t / 0.002
            shock = (1.0 - st * 1.8) * 1.4
            
        # Compressed chamber punch
        env_thump = math.exp(-t * 36.0)
        thump = lp_punch(brownian[i]) * 5.0 * env_thump
        thump = math.tanh(thump * 2.5)
        
        # High-velocity crackle
        env_crack = math.exp(-t * 48.0)
        crack = bp_crack(white) * env_crack * 1.3
        
        # Tail
        tail = math.exp(-t * 20.0) * white * 0.25
        
        sig = shock + thump * 0.75 + crack * 0.8 + tail
        samples.append(math.tanh(sig) * 0.92)
    return samples

def make_tactical_minigun_fire() -> list[float]:
    """Minigun 20Hz cyclic shot: rapid kinetic snap, high punch."""
    dur = 0.075
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_thump = create_lowpass_filter(180.0)
    bp_snap = create_bandpass_filter(1300.0, 800.0)
    brownian = create_brownian_noise(n)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        white = (random.random() * 2.0 - 1.0)
        env = math.exp(-t * 55.0)
        thump = math.tanh(lp_thump(brownian[i]) * 6.0 * env)
        snap = bp_snap(white) * env * 1.2
        sig = thump * 0.75 + snap * 0.85
        samples.append(math.tanh(sig) * 0.95)
    return samples

def make_tactical_minigun_spin() -> list[float]:
    """High-torque electric motor spooling: multi-pole rotor flutter and air rushing."""
    dur = 0.35
    n = int(SAMPLE_RATE * dur)
    samples = []
    bp_motor = create_bandpass_filter(450.0, 200.0)
    for i in range(n):
        t = i / SAMPLE_RATE
        white = (random.random() * 2.0 - 1.0)
        # Rotary aerodynamic flutter
        flutter_rate = 18.0 + (t / dur) * 35.0
        flutter = 0.6 + 0.4 * math.sin(2.0 * math.pi * flutter_rate * t)
        air = bp_motor(white) * flutter * min(1.0, t * 12.0) * 0.65
        samples.append(math.tanh(air) * 0.7)
    return samples

def make_tactical_flame_loop() -> list[float]:
    """Turbulent roaring high-pressure propellant combustion."""
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_roar = create_lowpass_filter(320.0)
    bp_rush = create_bandpass_filter(850.0, 600.0)
    brownian = create_brownian_noise(n)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        white = (random.random() * 2.0 - 1.0)
        # Random combustion turbulence
        mod = 0.7 + 0.3 * math.sin(2.0 * math.pi * 16.0 * t)
        low_roar = lp_roar(brownian[i]) * 3.5 * mod
        rush = bp_rush(white) * 0.4 * mod
        sig = math.tanh(low_roar + rush) * 0.8
        samples.append(sig)
    return samples

# --- VISCERAL ZOMBIE & MONSTER MODELS (ZERO SINE WAVES) ---

def make_visceral_zombie_groan() -> list[float]:
    """Guttural undead vocal fry & formant resonance (human infected throat rasp)."""
    dur = 0.65
    n = int(SAMPLE_RATE * dur)
    samples = []
    # Dual vocal tract formants for human guttural moan (/o/ - /u/)
    bp_f1 = create_bandpass_filter(380.0, 120.0)
    bp_f2 = create_bandpass_filter(850.0, 180.0)
    
    pulse_phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        
        # Glottal pulse train at 26Hz (vocal fry)
        pulse_freq = 24.0 + math.sin(t * 7.0) * 5.0
        pulse_phase += pulse_freq / SAMPLE_RATE
        if pulse_phase >= 1.0: pulse_phase -= 1.0
        glottal_pulse = 1.0 if pulse_phase < 0.12 else -0.15
        
        # Throat breath noise
        breath = (random.random() * 2.0 - 1.0) * 0.35
        raw_vocal = glottal_pulse + breath
        
        # Formant resonant filtering
        formant1 = bp_f1(raw_vocal) * 1.3
        formant2 = bp_f2(raw_vocal) * 0.8
        
        sig = (formant1 + formant2) * env * 1.4
        samples.append(math.tanh(sig) * 0.85)
    return samples

def make_visceral_zombie_aggro() -> list[float]:
    """Aggressive zombie snarl: raspy throat constriction and frenzied hiss."""
    dur = 0.45
    n = int(SAMPLE_RATE * dur)
    samples = []
    bp_snarl1 = create_bandpass_filter(580.0, 220.0)
    bp_snarl2 = create_bandpass_filter(1450.0, 450.0)
    
    pulse_phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        
        pulse_freq = 42.0 + math.sin(t * 12.0) * 8.0
        pulse_phase += pulse_freq / SAMPLE_RATE
        if pulse_phase >= 1.0: pulse_phase -= 1.0
        glottal = 1.0 if pulse_phase < 0.18 else -0.2
        
        friction = (random.random() * 2.0 - 1.0) * 0.65
        source = glottal + friction
        sig = (bp_snarl1(source) * 1.2 + bp_snarl2(source) * 0.9) * env * 1.5
        samples.append(math.tanh(sig) * 0.88)
    return samples

def make_visceral_dog_bark() -> list[float]:
    """Infected plague hound bark: sharp glottal snap + canine throat snarl."""
    dur = 0.24
    n = int(SAMPLE_RATE * dur)
    samples = []
    bp_canine1 = create_bandpass_filter(720.0, 250.0)
    bp_canine2 = create_bandpass_filter(1650.0, 500.0)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 18.0)
        
        # Sharp throat snap
        snap = 0.0
        if t < 0.015:
            snap = (random.random() * 2.0 - 1.0) * 1.5
            
        white = (random.random() * 2.0 - 1.0)
        snarl = (bp_canine1(white) * 1.4 + bp_canine2(white) * 0.9) * env
        sig = snap + snarl
        samples.append(math.tanh(sig * 1.3) * 0.9)
    return samples

def make_visceral_mutant_roar() -> list[float]:
    """Seismic Super Mutant roar: subharmonic earth-shaking chest rumble & cavernous throat."""
    dur = 0.95
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_sub = create_lowpass_filter(55.0)
    bp_throat1 = create_bandpass_filter(220.0, 90.0)
    bp_throat2 = create_bandpass_filter(460.0, 140.0)
    brownian = create_brownian_noise(n)
    
    pulse_phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin((t / dur) * math.pi)
        
        # Massive sub-bass displacement
        sub = lp_sub(brownian[i]) * 4.5 * env
        
        # Deep guttural chest resonance
        pulse_freq = 18.0 + math.sin(t * 6.0) * 4.0
        pulse_phase += pulse_freq / SAMPLE_RATE
        if pulse_phase >= 1.0: pulse_phase -= 1.0
        pulse = 1.2 if pulse_phase < 0.2 else -0.3
        
        white = (random.random() * 2.0 - 1.0) * 0.45
        source = pulse + white
        throat = (bp_throat1(source) * 1.6 + bp_throat2(source) * 1.1) * env
        
        sig = math.tanh(sub * 1.5 + throat * 1.4) * 0.96
        samples.append(sig)
    return samples

def make_cinematic_explosion() -> list[float]:
    """Devastating shockwave blast: supersonic front + rolling earthquake rumble."""
    dur = 0.85
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_sub = create_lowpass_filter(60.0)
    bp_fire = create_bandpass_filter(450.0, 350.0)
    brownian = create_brownian_noise(n)
    
    for i in range(n):
        t = i / SAMPLE_RATE
        white = (random.random() * 2.0 - 1.0)
        
        # Supersonic detonation front (0 - 8ms)
        shock = 0.0
        if t < 0.008:
            st = t / 0.008
            shock = (1.0 - st * 1.5) * 1.8
            
        # Rolling sub-bass rumble
        env_sub = math.exp(-t * 4.5)
        sub = lp_sub(brownian[i]) * 6.0 * env_sub
        
        # Fireball expansion
        env_fire = math.exp(-t * 9.0)
        fire = bp_fire(white) * env_fire * 1.8
        
        sig = shock + math.tanh(sub) * 0.95 + math.tanh(fire) * 0.8
        samples.append(math.tanh(sig) * 0.98)
    return samples

def make_muted_casing_ping() -> list[float]:
    """Muted brass shell casing bounce on concrete (short metallic clink, NOT a loud bell)."""
    dur = 0.06
    n = int(SAMPLE_RATE * dur)
    samples = []
    bp_brass = create_bandpass_filter(2600.0, 300.0)
    for i in range(n):
        t = i / SAMPLE_RATE
        white = (random.random() * 2.0 - 1.0)
        env = math.exp(-t * 70.0) # very fast decay
        ping = bp_brass(white) * env * 0.35
        samples.append(ping)
    return samples

def make_tactical_keycard_chirp() -> list[float]:
    """Low-profile electronic card reader verification chirp (subtle, high-tech, not arcade)."""
    dur = 0.08
    n = int(SAMPLE_RATE * dur)
    samples = []
    lp_smooth = create_lowpass_filter(1400.0)
    for i in range(n):
        t = i / SAMPLE_RATE
        # Soft two-tone micro-chirp
        freq = 920.0 if t < 0.035 else 1250.0
        env = math.sin((t / dur) * math.pi)
        tone = math.sin(2.0 * math.pi * freq * t) * env * 0.3
        samples.append(lp_smooth(tone))
    return samples

# --- MAIN GENERATOR & EXTRACTOR ---
def main():
    print("=== BUILDING AUTHENTIC TACTICAL AUDIO PIPELINE ===")
    
    # 1. Download Kenney Impact Sounds for Real Foley & Hits
    kenney_zip_url = "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip"
    print(f"Downloading authentic recorded foley from {kenney_zip_url}...")
    try:
        req = urllib.request.Request(kenney_zip_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as resp:
            zdata = io.BytesIO(resp.read())
            with zipfile.ZipFile(zdata) as zf:
                # Extract real footsteps
                with open("assets/audio/foley/footstep_concrete.ogg", "wb") as f:
                    f.write(zf.read("Audio/footstep_concrete_001.ogg"))
                with open("assets/audio/foley/footstep_gravel.ogg", "wb") as f:
                    f.write(zf.read("Audio/footstep_grass_002.ogg"))
                with open("assets/audio/foley/footstep_metal.ogg", "wb") as f:
                    f.write(zf.read("Audio/impactMetal_light_002.ogg"))
                
                # Extract real flesh hits (zero cartoon beeps)
                with open("assets/audio/zombies/zombie_hurt.ogg", "wb") as f:
                    f.write(zf.read("Audio/impactPunch_heavy_002.ogg"))
                with open("assets/audio/pickups/hit.ogg", "wb") as f:
                    f.write(zf.read("Audio/impactPunch_heavy_000.ogg"))
                with open("assets/audio/zombies/rock_impact.ogg", "wb") as f:
                    f.write(zf.read("Audio/impactPlate_heavy_001.ogg"))
                with open("assets/audio/environment/gate_slam.ogg", "wb") as f:
                    f.write(zf.read("Audio/impactMetal_heavy_001.ogg"))
                with open("assets/audio/weapons/dry_fire.ogg", "wb") as f:
                    f.write(zf.read("Audio/impactGeneric_light_003.ogg"))
                    
        print("  -> Successfully extracted Kenney recorded foley and impact files.")
    except Exception as e:
        print("  -> Warning downloading Kenney foley:", e)
    
    # 2. Synthesize High-Fidelity Tactical Weapons (zero pure sine waves)
    print("Synthesizing realistic tactical weapons & ballistics...")
    write_wav("assets/audio/weapons/pistol.wav", make_tactical_pistol())
    write_wav("assets/audio/weapons/shotgun.wav", make_tactical_shotgun())
    write_wav("assets/audio/weapons/shotgun_pump.wav", make_tactical_shotgun_pump())
    write_wav("assets/audio/weapons/rifle.wav", make_tactical_rifle())
    write_wav("assets/audio/weapons/minigun_fire.wav", make_tactical_minigun_fire())
    write_wav("assets/audio/weapons/minigun_spin.wav", make_tactical_minigun_spin())
    write_wav("assets/audio/weapons/flame_loop.wav", make_tactical_flame_loop())
    write_wav("assets/audio/weapons/flame_start.wav", make_tactical_flame_loop()[:int(SAMPLE_RATE * 0.25)])
    write_wav("assets/audio/weapons/casing_1.wav", make_muted_casing_ping())
    write_wav("assets/audio/weapons/casing_2.wav", make_muted_casing_ping())
    write_wav("assets/audio/weapons/casing_3.wav", make_muted_casing_ping())
    
    # 3. Synthesize Visceral Zombie & Monster Vocalizations (Glottal pulses + formants)
    print("Synthesizing visceral horror vocalizations...")
    write_wav("assets/audio/zombies/zombie_idle.wav", make_visceral_zombie_groan())
    write_wav("assets/audio/zombies/zombie_aggro.wav", make_visceral_zombie_aggro())
    write_wav("assets/audio/zombies/zombie_death.wav", make_visceral_zombie_groan())
    write_wav("assets/audio/zombies/dog_bark.wav", make_visceral_dog_bark())
    write_wav("assets/audio/zombies/dog_whoosh.wav", make_tactical_pistol()[:int(SAMPLE_RATE * 0.18)])
    write_wav("assets/audio/zombies/mutant_roar.wav", make_visceral_mutant_roar())
    write_wav("assets/audio/zombies/mutant_step.wav", make_cinematic_explosion()[:int(SAMPLE_RATE * 0.35)])
    write_wav("assets/audio/zombies/stomp_crash.wav", make_cinematic_explosion()[:int(SAMPLE_RATE * 0.50)])
    
    # 4. Synthesize Environment & Tactical Pickups
    print("Synthesizing environment and tactical pickups...")
    write_wav("assets/audio/environment/explosion.wav", make_cinematic_explosion())
    write_wav("assets/audio/pickups/keycard_chirp.wav", make_tactical_keycard_chirp())
    write_wav("assets/audio/pickups/pickup_ammo.wav", make_tactical_shotgun_pump())
    write_wav("assets/audio/pickups/pickup_health.wav", make_tactical_flame_loop()[:int(SAMPLE_RATE * 0.22)])
    
    print("=== TACTICAL AUDIO REPLACEMENT COMPLETE ===")

if __name__ == "__main__":
    main()
