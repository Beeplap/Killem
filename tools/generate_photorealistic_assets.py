import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUTPUT_DIR = "assets/textures"

def ensure_dirs():
    dirs = [
        f"{OUTPUT_DIR}/ground",
        f"{OUTPUT_DIR}/railway",
        f"{OUTPUT_DIR}/environment",
        f"{OUTPUT_DIR}/props",
        f"{OUTPUT_DIR}/decals",
        f"{OUTPUT_DIR}/lighting",
        f"{OUTPUT_DIR}/characters",
        f"{OUTPUT_DIR}/ui"
    ]
    for d in dirs:
        os.makedirs(d, exist_ok=True)

def generate_fractal_noise(w, h, scale=20.0, octaves=5, persistence=0.5):
    res = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    freq = 1.0
    tot_amp = 0.0
    for _ in range(octaves):
        gw = max(2, int(w / (scale / freq)))
        gh = max(2, int(h / (scale / freq)))
        rg = np.random.rand(gh, gw).astype(np.float32)
        im = Image.fromarray((rg * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BICUBIC)
        res += (np.array(im, dtype=np.float32) / 255.0) * amp
        tot_amp += amp
        amp *= persistence
        freq *= 2.0
    return res / tot_amp

# -------------------------------------------------------------
# 1. UI: TACTICAL CROSSHAIRS
# -------------------------------------------------------------
def make_crosshairs():
    size = 32
    center = size // 2
    
    # 1. Normal Aiming Crosshair
    normal = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dn = ImageDraw.Draw(normal)
    # Center dot
    dn.ellipse([center - 1, center - 1, center + 1, center + 1], fill=(240, 245, 255, 240))
    # 4 Tactical Tick Marks
    gap = 4
    length = 7
    # Left, Right, Up, Down
    dn.line([(center - gap - length, center), (center - gap, center)], fill=(220, 230, 240, 220), width=1)
    dn.line([(center + gap, center), (center + gap + length, center)], fill=(220, 230, 240, 220), width=1)
    dn.line([(center, center - gap - length), (center, center - gap)], fill=(220, 230, 240, 220), width=1)
    dn.line([(center, center + gap), (center, center + gap + length)], fill=(220, 230, 240, 220), width=1)
    # Subtle corner brackets
    dn.arc([center - 11, center - 11, center + 11, center + 11], 0, 360, fill=(180, 190, 205, 90), width=1)
    normal.save(f"{OUTPUT_DIR}/ui/crosshair_normal.png")
    
    # 2. Shooting / Firing Crosshair (Expanded, Intense Red Combat Glow)
    shooting = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shooting)
    # Glowing hot center dot
    ds.ellipse([center - 2, center - 2, center + 2, center + 2], fill=(255, 60, 40, 255))
    ds.ellipse([center - 1, center - 1, center + 1, center + 1], fill=(255, 255, 240, 255))
    # Expanded recoil ticks
    gap_s = 7
    length_s = 6
    ds.line([(center - gap_s - length_s, center), (center - gap_s, center)], fill=(255, 40, 30, 255), width=2)
    ds.line([(center + gap_s, center), (center + gap_s + length_s, center)], fill=(255, 40, 30, 255), width=2)
    ds.line([(center, center - gap_s - length_s), (center, center - gap_s)], fill=(255, 40, 30, 255), width=2)
    ds.line([(center, center + gap_s), (center, center + gap_s + length_s)], fill=(255, 40, 30, 255), width=2)
    # Recoil outer ring
    ds.arc([center - 13, center - 13, center + 13, center + 13], 0, 360, fill=(255, 50, 40, 160), width=1)
    shooting.save(f"{OUTPUT_DIR}/ui/crosshair_shooting.png")
    print("Saved tactical crosshairs.")

# -------------------------------------------------------------
# 2. PHOTOREALISTIC GROUND & RAILWAY
# -------------------------------------------------------------
def make_photorealistic_ground():
    w, h = 512, 512
    # Detailed dark soil with organic grit
    n_macro = generate_fractal_noise(w, h, scale=64.0, octaves=4, persistence=0.5)
    n_micro = generate_fractal_noise(w, h, scale=8.0, octaves=4, persistence=0.6)
    fine = np.random.rand(h, w).astype(np.float32) * 0.12
    
    comb = n_macro * 0.6 + n_micro * 0.3 + fine
    # Gritty desaturated earth palette (38, 34, 30 base)
    r = np.clip(38 + comb * 30, 20, 75).astype(np.uint8)
    g = np.clip(34 + comb * 26, 18, 68).astype(np.uint8)
    b = np.clip(30 + comb * 22, 16, 60).astype(np.uint8)
    
    img = Image.fromarray(np.stack([r, g, b], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)
    # Micro pebbles
    np.random.seed(99)
    for _ in range(500):
        px = np.random.randint(0, w)
        py = np.random.randint(0, h)
        rad = np.random.randint(1, 3)
        shade = np.random.randint(65, 95)
        draw.ellipse([px - rad, py - rad, px + rad, py + rad], fill=(shade, shade - 3, shade - 8))
    img.save(f"{OUTPUT_DIR}/ground/dirt_terrain.png")
    
    # Cracked Cold Asphalt
    n_asph = generate_fractal_noise(w, h, scale=12.0, octaves=4, persistence=0.55)
    asph_val = np.clip(35 + n_asph * 35 + fine * 20, 25, 78).astype(np.uint8)
    asph_img = Image.fromarray(np.stack([asph_val, asph_val + 2, asph_val + 4], axis=-1), mode="RGB")
    d_asph = ImageDraw.Draw(asph_img)
    # Sub-pixel branching fracture cracks
    for _ in range(16):
        cx = np.random.randint(10, w - 10)
        cy = np.random.randint(10, h - 10)
        angle = np.random.rand() * math.tau
        steps = np.random.randint(25, 60)
        for _ in range(steps):
            nx = cx + math.cos(angle) * 3.5 + np.random.randn() * 1.2
            ny = cy + math.sin(angle) * 3.5 + np.random.randn() * 1.2
            d_asph.line([(cx + 1, cy + 1), (nx + 1, ny + 1)], fill=(58, 62, 68), width=1)
            d_asph.line([(cx, cy), (nx, ny)], fill=(14, 15, 18), width=2)
            if np.random.rand() < 0.25:
                angle += np.random.uniform(-0.7, 0.7)
            cx, ny = nx, ny
    asph_img.save(f"{OUTPUT_DIR}/ground/cracked_asphalt.png")
    print("Saved photorealistic ground textures.")

# -------------------------------------------------------------
# 3. 2.5D REALISTIC CHARACTERS (8 DIRECTIONS, 96x96 FRAME)
# -------------------------------------------------------------
def render_realistic_soldier_frame(angle_rad, size=96):
    """Render a realistic SWAT operative with digital camo, tactical Kevlar vest, boots, helmet, assault rifle."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    # Realistic soft ground shadow (elliptical ambient occlusion)
    draw.ellipse([cx - 18, cy + 24, cx + 18, cy + 38], fill=(12, 14, 16, 140))
    draw.ellipse([cx - 14, cy + 26, cx + 14, cy + 36], fill=(8, 9, 10, 180))
    
    # Combat Pants & Boots (Desaturated military olive/grey camouflage)
    boot_color = (22, 24, 26)
    camo_dark = (38, 44, 36)
    camo_light = (48, 54, 46)
    
    # Left and Right Legs
    draw.rectangle([cx - 11, cy + 12, cx - 2, cy + 28], fill=camo_dark)
    draw.rectangle([cx + 2, cy + 12, cx + 11, cy + 28], fill=camo_dark)
    # Boots with tread
    draw.rectangle([cx - 12, cy + 27, cx - 1, cy + 34], fill=boot_color)
    draw.rectangle([cx + 1, cy + 27, cx + 12, cy + 34], fill=boot_color)
    draw.line([(cx - 12, cy + 33), (cx - 1, cy + 33)], fill=(45, 48, 52), width=1)
    draw.line([(cx + 1, cy + 33), (cx + 12, cy + 33)], fill=(45, 48, 52), width=1)
    
    # Torso & Tactical Kevlar Vest
    vest_dark = (26, 30, 34)
    vest_plate = (35, 40, 46)
    draw.ellipse([cx - 15, cy - 8, cx + 15, cy + 16], fill=vest_dark)
    draw.rectangle([cx - 10, cy - 5, cx + 10, cy + 12], fill=vest_plate)
    # Mag pouches on vest front
    if sin_a > -0.2:
        for px in [-6, -1, 4]:
            draw.rectangle([cx + px, cy + 3, cx + px + 3, cy + 10], fill=(20, 22, 25))
    
    # Shoulders
    sh_x = -sin_a * 12
    sh_y = cos_a * 7
    draw.circle((cx - sh_x, cy - 2 - sh_y), 7, fill=vest_dark)
    draw.circle((cx + sh_x, cy - 2 + sh_y), 7, fill=vest_dark)
    
    # Tactical Assault Rifle (Matte black steel with barrel extension)
    gx = cx + cos_a * 10
    gy = cy + sin_a * 8 - 4
    g_end_x = gx + cos_a * 30
    g_end_y = gy + sin_a * 30
    # Weapon receiver, rail, and barrel
    draw.line([(gx, gy), (g_end_x, g_end_y)], fill=(16, 18, 20), width=5)
    draw.line([(gx + cos_a * 8, gy + sin_a * 8), (gx + cos_a * 24, gy + sin_a * 24)], fill=(55, 60, 65), width=3)
    draw.line([(gx + cos_a * 12, gy + sin_a * 12), (gx + cos_a * 28, gy + sin_a * 28)], fill=(85, 90, 95), width=1) # Specular edge
    # Hands in tactical tactical gloves
    glove_col = (30, 32, 35)
    draw.circle((gx + cos_a * 10, gy + sin_a * 10), 4, fill=glove_col)
    draw.circle((gx + cos_a * 20, gy + sin_a * 20), 4, fill=glove_col)
    
    # Helmet & Visor (Ballistic combat helmet)
    head_y = cy - 10
    draw.circle((cx, head_y), 10, fill=(32, 38, 30))
    draw.ellipse([cx - 9, head_y - 2, cx + 9, head_y + 8], fill=(24, 28, 24))
    # Tactical night-vision / ballistic goggles
    if sin_a > -0.35:
        vx = cx + cos_a * 6
        vy = head_y + sin_a * 4 + 2
        draw.ellipse([vx - 5, vy - 2, vx + 5, vy + 3], fill=(20, 110, 160))
        draw.line([(vx - 3, vy), (vx + 3, vy)], fill=(160, 220, 255), width=1) # Specular glint
        
    return img

def render_realistic_walker_frame(angle_rad, size=96):
    """Render a realistic decaying walker zombie with necrotic desaturated skin and tattered clothing."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    # Ground shadow
    draw.ellipse([cx - 16, cy + 22, cx + 16, cy + 34], fill=(10, 12, 14, 150))
    
    # Necrotic flesh palette: desaturated greyish olive-drab with bruising
    skin_col = (88, 98, 80)
    skin_dark = (65, 74, 60)
    blood_dark = (95, 18, 18)
    jeans_tattered = (38, 44, 52)
    jacket_tattered = (48, 42, 38)
    
    # Legs in ripped jeans
    draw.rectangle([cx - 9, cy + 12, cx - 2, cy + 27], fill=jeans_tattered)
    draw.rectangle([cx + 2, cy + 12, cx + 9, cy + 27], fill=jeans_tattered)
    draw.rectangle([cx - 10, cy + 26, cx - 1, cy + 32], fill=(28, 26, 24))
    draw.rectangle([cx + 1, cy + 26, cx + 10, cy + 32], fill=(28, 26, 24))
    # Exposed decaying knee bone
    draw.circle((cx - 5, cy + 20), 2, fill=(160, 155, 145))
    
    # Torso with ripped jacket and exposed ribs / wounds
    draw.ellipse([cx - 14, cy - 8, cx + 14, cy + 15], fill=jacket_tattered)
    draw.ellipse([cx - 6, cy - 2, cx + 5, cy + 8], fill=blood_dark)
    draw.line([(cx - 3, cy + 1), (cx + 3, cy + 1)], fill=(155, 150, 140), width=1) # rib bone
    
    # Reaching / Lunging Rotting Arms
    for side in [-9, 9]:
        ax = cx + side * (-sin_a) + cos_a * 5
        ay = cy + side * (cos_a) + sin_a * 5
        a_end_x = ax + cos_a * 24
        a_end_y = ay + sin_a * 24
        draw.line([(ax, ay), (a_end_x, a_end_y)], fill=skin_col, width=4)
        draw.circle((a_end_x, a_end_y), 3, fill=blood_dark) # Bloody clawing fingers
        
    # Decayed Head
    head_y = cy - 10
    draw.circle((cx, head_y), 9, fill=skin_col)
    draw.ellipse([cx - 7, head_y + 2, cx + 7, head_y + 8], fill=skin_dark)
    if sin_a > -0.4:
        ex = cx + cos_a * 5
        ey = head_y + sin_a * 4
        draw.circle((ex, ey), 2, fill=(180, 25, 20)) # Sunken red glowing eye
        # Gaping necrotic jaw
        draw.ellipse([ex - 2, ey + 4, ex + 2, ey + 7], fill=(20, 8, 8))
        
    return img

def render_realistic_dog_frame(angle_rad, size=96):
    """Render a realistic feral hound predator with decaying hide and exposed musculature."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    # Shadow
    draw.ellipse([cx - 20, cy + 14, cx + 20, cy + 28], fill=(10, 12, 14, 150))
    
    hide_dark = (72, 45, 34)
    muscle_raw = (115, 35, 28)
    bone_color = (175, 170, 158)
    
    # Elongated predatory spine
    p1_x = cx - cos_a * 18
    p1_y = cy - sin_a * 18
    p2_x = cx + cos_a * 18
    p2_y = cy + sin_a * 18
    draw.line([(p1_x, p1_y), (p2_x, p2_y)], fill=hide_dark, width=14)
    draw.line([(cx - cos_a * 6, cy - sin_a * 6), (cx + cos_a * 6, cy + sin_a * 6)], fill=muscle_raw, width=10)
    
    # Exposed ribcage
    for roff in [-6, 0, 6]:
        rx = cx + cos_a * roff
        ry = cy + sin_a * roff
        draw.line([(rx - sin_a * 6, ry + cos_a * 6), (rx + sin_a * 6, ry - cos_a * 6)], fill=bone_color, width=2)
        
    # Snout and savage jaws
    snout_x = cx + cos_a * 26
    snout_y = cy + sin_a * 26
    draw.circle((snout_x, snout_y), 7, fill=hide_dark)
    draw.polygon([(snout_x + cos_a * 4, snout_y + sin_a * 4),
                  (snout_x - sin_a * 4, snout_y + cos_a * 4),
                  (snout_x + sin_a * 4, snout_y - cos_a * 4)], fill=muscle_raw)
    # Fangs
    draw.circle((snout_x + cos_a * 4, snout_y + sin_a * 4), 2, fill=(245, 245, 235))
    draw.circle((snout_x, snout_y - 2), 2, fill=(220, 30, 20))
    
    return img

def render_realistic_heavy_frame(angle_rad, size=128):
    """Render a massive realistic mutant brute with bolted scrap armor and scarred muscle."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    # Heavy Shadow
    draw.ellipse([cx - 28, cy + 32, cx + 28, cy + 50], fill=(8, 10, 12, 175))
    
    brute_skin = (98, 88, 80)
    scrap_iron = (45, 48, 52)
    rust = (105, 52, 32)
    
    # Thick Legs
    draw.rectangle([cx - 16, cy + 18, cx - 4, cy + 42], fill=(32, 34, 38))
    draw.rectangle([cx + 4, cy + 18, cx + 16, cy + 42], fill=(32, 34, 38))
    
    # Massive mutant torso with welded metal plates
    draw.ellipse([cx - 26, cy - 18, cx + 26, cy + 22], fill=brute_skin)
    draw.rectangle([cx - 20, cy - 14, cx + 20, cy + 16], fill=scrap_iron)
    # Welded seam and rust streaks
    draw.line([(cx - 20, cy), (cx + 20, cy)], fill=rust, width=3)
    draw.line([(cx, cy - 14), (cx, cy + 16)], fill=(25, 26, 28), width=2)
    
    # Massive mutant fists and shoulders
    for side in [-22, 22]:
        sx = cx + side * (-sin_a) + cos_a * 10
        sy = cy + side * (cos_a) + sin_a * 10
        draw.circle((sx, sy), 14, fill=brute_skin)
        f_end_x = sx + cos_a * 26
        f_end_y = sy + sin_a * 26
        draw.line([(sx, sy), (f_end_x, f_end_y)], fill=brute_skin, width=10)
        draw.circle((f_end_x, f_end_y), 7, fill=scrap_iron) # Iron knuckle plate
        
    # Brutish pinhead skull
    head_y = cy - 20
    draw.circle((cx + cos_a * 6, head_y + sin_a * 4), 12, fill=brute_skin)
    draw.circle((cx + cos_a * 10, head_y + sin_a * 4), 3, fill=(240, 35, 20))
    
    return img

def render_spitter_frame(angle_rad, size=96):
    """Render an acid-mutated spitter zombie with sickly glowing toxic bile pustules."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    draw.ellipse([cx - 15, cy + 22, cx + 15, cy + 34], fill=(10, 12, 14, 150))
    
    skin = (72, 95, 68)
    bile = (120, 225, 45) # Toxic glowing bile
    bile_glow = (60, 140, 25)
    
    # Legs
    draw.rectangle([cx - 8, cy + 12, cx - 2, cy + 28], fill=(35, 42, 38))
    draw.rectangle([cx + 2, cy + 12, cx + 8, cy + 28], fill=(35, 42, 38))
    
    # Swollen torso with glowing pustules
    draw.ellipse([cx - 14, cy - 8, cx + 14, cy + 16], fill=skin)
    # Toxic green pustules
    draw.circle((cx - 5, cy + 2), 4, fill=bile_glow)
    draw.circle((cx - 5, cy + 2), 2, fill=bile)
    draw.circle((cx + 6, cy - 2), 5, fill=bile_glow)
    draw.circle((cx + 6, cy - 2), 3, fill=bile)
    
    # Claws
    for side in [-9, 9]:
        ax = cx + side * (-sin_a) + cos_a * 6
        ay = cy + side * (cos_a) + sin_a * 6
        draw.line([(ax, ay), (ax + cos_a * 22, ay + sin_a * 22)], fill=skin, width=4)
        draw.circle((ax + cos_a * 22, ay + sin_a * 22), 3, fill=bile)
        
    # Distended glowing maw
    head_y = cy - 10
    draw.circle((cx, head_y), 9, fill=skin)
    if sin_a > -0.4:
        ex = cx + cos_a * 5
        ey = head_y + sin_a * 4
        draw.ellipse([ex - 3, ey + 2, ex + 3, ey + 7], fill=bile)
        draw.circle((ex, ey - 2), 2, fill=(220, 255, 60))
        
    return img

def render_armored_frame(angle_rad, size=96):
    """Render an infected military SWAT commando with riot helmet and bulletproof armor."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    draw.ellipse([cx - 18, cy + 24, cx + 18, cy + 36], fill=(10, 12, 14, 160))
    
    armor_dark = (32, 35, 40)
    armor_edge = (55, 60, 68)
    blood = (110, 20, 20)
    
    # Heavy armored greaves
    draw.rectangle([cx - 11, cy + 12, cx - 2, cy + 29], fill=armor_dark)
    draw.rectangle([cx + 2, cy + 12, cx + 11, cy + 29], fill=armor_dark)
    draw.rectangle([cx - 12, cy + 28, cx - 1, cy + 35], fill=(20, 22, 24))
    draw.rectangle([cx + 1, cy + 28, cx + 12, cy + 35], fill=(20, 22, 24))
    
    # Heavy Kevlar Chestplate with blood splatters
    draw.ellipse([cx - 16, cy - 8, cx + 16, cy + 16], fill=armor_dark)
    draw.rectangle([cx - 12, cy - 6, cx + 12, cy + 13], fill=armor_edge)
    draw.ellipse([cx - 4, cy - 1, cx + 6, cy + 9], fill=blood)
    
    # Arms in tactical sleeves
    for side in [-10, 10]:
        ax = cx + side * (-sin_a) + cos_a * 6
        ay = cy + side * (cos_a) + sin_a * 6
        draw.line([(ax, ay), (ax + cos_a * 24, ay + sin_a * 24)], fill=armor_dark, width=5)
        draw.circle((ax + cos_a * 24, ay + sin_a * 24), 4, fill=(55, 60, 65))
        
    # Ballistic Riot Helmet with broken glass visor
    head_y = cy - 10
    draw.circle((cx, head_y), 11, fill=(28, 30, 34))
    if sin_a > -0.35:
        vx = cx + cos_a * 6
        vy = head_y + sin_a * 4 + 2
        draw.ellipse([vx - 6, vy - 3, vx + 6, vy + 4], fill=(80, 140, 160))
        draw.line([(vx - 4, vy - 1), (vx + 2, vy + 2)], fill=(255, 255, 255), width=1) # crack
        draw.circle((vx - 2, vy), 2, fill=(220, 30, 20)) # red eye behind visor
        
    return img

def render_colossus_frame(angle_rad, size=144):
    """Render an enormous mutant Colossus boss with ground-slam fists and magma fissures."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    # Colossal Shadow
    draw.ellipse([cx - 36, cy + 42, cx + 36, cy + 64], fill=(6, 8, 10, 190))
    
    col_skin = (75, 68, 65)
    magma = (245, 95, 20)
    magma_glow = (180, 40, 15)
    steel = (38, 40, 44)
    
    # Enormous Tree-trunk legs
    draw.rectangle([cx - 20, cy + 22, cx - 4, cy + 54], fill=(28, 30, 32))
    draw.rectangle([cx + 4, cy + 22, cx + 20, cy + 54], fill=(28, 30, 32))
    
    # Colossal mutated torso with glowing volcanic fissures
    draw.ellipse([cx - 32, cy - 24, cx + 32, cy + 26], fill=col_skin)
    # Magma crack fissures
    draw.line([(cx - 18, cy - 10), (cx, cy + 14)], fill=magma, width=3)
    draw.line([(cx + 18, cy - 14), (cx + 4, cy + 12)], fill=magma, width=2)
    draw.line([(cx - 8, cy), (cx + 12, cy - 4)], fill=(255, 220, 60), width=1)
    
    # Giant ground-pound fists
    for side in [-28, 28]:
        sx = cx + side * (-sin_a) + cos_a * 12
        sy = cy + side * (cos_a) + sin_a * 12
        draw.circle((sx, sy), 18, fill=col_skin)
        f_end_x = sx + cos_a * 34
        f_end_y = sy + sin_a * 34
        draw.line([(sx, sy), (f_end_x, f_end_y)], fill=col_skin, width=14)
        draw.circle((f_end_x, f_end_y), 11, fill=steel) # Huge iron wrecking plate
        
    # Grotesque horned mutant skull
    head_y = cy - 28
    draw.circle((cx + cos_a * 8, head_y + sin_a * 5), 15, fill=col_skin)
    draw.polygon([(cx + cos_a * 6 - 8, head_y - 8), (cx + cos_a * 6 - 16, head_y - 20), (cx + cos_a * 6 - 4, head_y - 12)], fill=(30, 28, 26)) # Horn
    draw.polygon([(cx + cos_a * 6 + 8, head_y - 8), (cx + cos_a * 6 + 16, head_y - 20), (cx + cos_a * 6 + 4, head_y - 12)], fill=(30, 28, 26))
    draw.circle((cx + cos_a * 12, head_y + sin_a * 5), 4, fill=magma)
    
    return img

def make_all_character_sheets():
    angles = [0, math.pi / 4, math.pi / 2, 3 * math.pi / 4, math.pi, -3 * math.pi / 4, -math.pi / 2, -math.pi / 4]
    
    # 1. Soldier (96x96 per frame, total 768x96)
    soldier_sheet = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_realistic_soldier_frame(a, size=96)
        soldier_sheet.paste(f, (i * 96, 0))
    soldier_sheet.save(f"{OUTPUT_DIR}/characters/soldier_8dir.png")
    
    # 2. Regular Walker (96x96 per frame)
    walker_sheet = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_realistic_walker_frame(a, size=96)
        walker_sheet.paste(f, (i * 96, 0))
    walker_sheet.save(f"{OUTPUT_DIR}/characters/zombie_regular_8dir.png")
    
    # 3. Infected Dog (96x96 per frame)
    dog_sheet = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_realistic_dog_frame(a, size=96)
        dog_sheet.paste(f, (i * 96, 0))
    dog_sheet.save(f"{OUTPUT_DIR}/characters/zombie_dog_8dir.png")
    
    # 4. Heavy Mutant Brute (128x128 per frame, total 1024x128)
    heavy_sheet = Image.new("RGBA", (128 * 8, 128), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_realistic_heavy_frame(a, size=128)
        heavy_sheet.paste(f, (i * 128, 0))
    heavy_sheet.save(f"{OUTPUT_DIR}/characters/zombie_heavy_8dir.png")
    
    # 5. Spitter Mutant (96x96 per frame)
    spitter_sheet = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_spitter_frame(a, size=96)
        spitter_sheet.paste(f, (i * 96, 0))
    spitter_sheet.save(f"{OUTPUT_DIR}/characters/zombie_spitter_8dir.png")
    
    # 6. Armored SWAT Zombie (96x96 per frame)
    armored_sheet = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_armored_frame(a, size=96)
        armored_sheet.paste(f, (i * 96, 0))
    armored_sheet.save(f"{OUTPUT_DIR}/characters/zombie_armored_8dir.png")
    
    # 7. Colossus Boss (144x144 per frame, total 1152x144)
    colossus_sheet = Image.new("RGBA", (144 * 8, 144), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_colossus_frame(a, size=144)
        colossus_sheet.paste(f, (i * 144, 0))
    colossus_sheet.save(f"{OUTPUT_DIR}/characters/zombie_colossus_8dir.png")
    
    print("Saved all 7 realistic character sheets.")

def main():
    ensure_dirs()
    make_crosshairs()
    make_photorealistic_ground()
    make_all_character_sheets()
    print("PHOTOREALISTIC ASSET PIPELINE COMPLETE!")

if __name__ == "__main__":
    main()
