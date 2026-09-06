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
        f"{OUTPUT_DIR}/characters"
    ]
    for d in dirs:
        os.makedirs(d, exist_ok=True)

def generate_noise(w, h, scale=10.0, octaves=4, persistence=0.5):
    """Generate multi-octave value noise."""
    res = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    freq = 1.0
    tot_amp = 0.0
    for _ in range(octaves):
        grid_w = max(2, int(w / (scale / freq)))
        grid_h = max(2, int(h / (scale / freq)))
        rand_grid = np.random.rand(grid_h, grid_w).astype(np.float32)
        im = Image.fromarray((rand_grid * 255).astype(np.uint8)).resize((w, h), Image.Resampling.BILINEAR)
        res += np.array(im, dtype=np.float32) / 255.0 * amp
        tot_amp += amp
        amp *= persistence
        freq *= 2.0
    return res / tot_amp

# -------------------------------------------------------------
# 1. GROUND TEXTURES
# -------------------------------------------------------------
def make_dirt_terrain():
    w, h = 512, 512
    n1 = generate_noise(w, h, scale=32.0, octaves=5, persistence=0.55)
    n2 = generate_noise(w, h, scale=8.0, octaves=3, persistence=0.6)
    fine = np.random.rand(h, w) * 0.15

    # Gritty muddy soil palette: dark charcoal brown with wet spots
    base_r, base_g, base_b = 44, 38, 32
    comb = n1 * 0.65 + n2 * 0.25 + fine

    r = np.clip(base_r * comb * 1.5, 20, 80).astype(np.uint8)
    g = np.clip(base_g * comb * 1.4, 18, 70).astype(np.uint8)
    b = np.clip(base_b * comb * 1.3, 16, 60).astype(np.uint8)

    img = Image.fromarray(np.stack([r, g, b], axis=-1), mode="RGB")
    # Add tiny stones / pebbles
    draw = ImageDraw.Draw(img)
    np.random.seed(42)
    for _ in range(350):
        px = np.random.randint(0, w)
        py = np.random.randint(0, h)
        rad = np.random.randint(1, 3)
        col = np.random.randint(70, 110)
        draw.ellipse([px - rad, py - rad, px + rad, py + rad], fill=(col, col - 5, col - 12))

    img.save(f"{OUTPUT_DIR}/ground/dirt_terrain.png")
    print("Saved dirt_terrain.png")

def make_cracked_asphalt():
    w, h = 512, 512
    n = generate_noise(w, h, scale=16.0, octaves=4, persistence=0.5)
    fine = np.random.rand(h, w) * 0.2

    # Cold dark asphalt
    comb = n * 0.8 + fine
    base = np.clip(32 + comb * 35, 22, 75).astype(np.uint8)
    img = Image.fromarray(np.stack([base, base + 2, base + 5], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)

    # Branching cracks
    np.random.seed(101)
    for _ in range(12):
        cx = np.random.randint(20, w - 20)
        cy = np.random.randint(20, h - 20)
        angle = np.random.rand() * math.tau
        steps = np.random.randint(20, 50)
        for s in range(steps):
            nx = cx + math.cos(angle) * 4.0 + np.random.randn() * 1.5
            ny = cy + math.sin(angle) * 4.0 + np.random.randn() * 1.5
            # Highlight crack edge
            draw.line([(cx + 1, cy + 1), (nx + 1, ny + 1)], fill=(55, 60, 68), width=2)
            # Dark crack fissure
            draw.line([(cx, cy), (nx, ny)], fill=(12, 14, 16), width=2)
            if np.random.rand() < 0.2:
                angle += np.random.uniform(-0.8, 0.8)
            cx, ny = nx, ny

    img.save(f"{OUTPUT_DIR}/ground/cracked_asphalt.png")
    print("Saved cracked_asphalt.png")

def make_dead_grass():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    np.random.seed(77)
    base_x, base_y = 64, 85
    # Shadow underneath
    draw.ellipse([base_x - 30, base_y - 8, base_x + 30, base_y + 12], fill=(10, 10, 10, 100))

    # Dry withered yellow-brown tuft
    for _ in range(45):
        blade_len = np.random.uniform(25, 55)
        angle = np.random.uniform(-math.pi * 0.75, -math.pi * 0.25)
        curve = np.random.uniform(-10, 10)
        ex = base_x + math.cos(angle) * blade_len + curve
        ey = base_y + math.sin(angle) * blade_len
        mid_x = (base_x + ex) / 2 + curve
        mid_y = (base_y + ey) / 2

        col_r = np.random.randint(95, 140)
        col_g = np.random.randint(85, 120)
        col_b = np.random.randint(35, 60)
        draw.line([(base_x + np.random.randint(-12, 12), base_y), (mid_x, mid_y), (ex, ey)],
                  fill=(col_r, col_g, col_b, 230), width=np.random.choice([1, 2]))

    img = img.filter(ImageFilter.SMOOTH_MORE)
    img.save(f"{OUTPUT_DIR}/ground/dead_grass.png")
    print("Saved dead_grass.png")

# -------------------------------------------------------------
# 2. RAILWAY TEXTURES
# -------------------------------------------------------------
def make_railway_track():
    w, h = 256, 256
    # Ballast gravel
    noise = generate_noise(w, h, scale=6.0, octaves=4, persistence=0.6)
    b = np.clip(55 + noise * 45, 35, 110).astype(np.uint8)
    img = Image.fromarray(np.stack([b, b, b + 4], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)

    # Wooden Ties (Sleepers) across track horizontally
    tie_y_positions = range(16, h, 48)
    for ty in tie_y_positions:
        # Shadow
        draw.rectangle([32, ty + 18, 224, ty + 24], fill=(18, 18, 20))
        # Tie body
        for y_sub in range(ty, ty + 18):
            wood_noise = int(np.sin(y_sub * 0.4) * 5 + np.random.randint(-8, 8))
            wr = max(20, min(255, 62 + wood_noise))
            wg = max(15, min(255, 45 + wood_noise))
            wb = max(10, min(255, 28 + wood_noise))
            draw.line([(34, y_sub), (222, y_sub)], fill=(wr, wg, wb), width=1)
        # Tie highlight top
        draw.line([(34, ty), (222, ty)], fill=(90, 68, 48), width=1)
        # Metal tie plates
        for px in [68, 188]:
            draw.rectangle([px - 8, ty + 2, px + 8, ty + 16], fill=(45, 48, 52))
            draw.rectangle([px - 4, ty + 5, px + 4, ty + 13], fill=(30, 32, 35))

    # Dual Steel Rails running vertically at x=68 and x=188
    for rx in [68, 188]:
        # Rail base shadow
        draw.line([(rx + 5, 0), (rx + 5, h)], fill=(15, 15, 18), width=3)
        # Rail foot (oxidized steel)
        draw.line([(rx - 4, 0), (rx - 4, h)], fill=(75, 52, 40), width=2)
        draw.line([(rx + 4, 0), (rx + 4, h)], fill=(75, 52, 40), width=2)
        # Rail web / flange
        draw.line([(rx, 0), (rx, h)], fill=(95, 80, 72), width=6)
        # Rail head (shiny polished chrome steel from train wheels)
        draw.line([(rx, 0), (rx, h)], fill=(185, 195, 210), width=3)
        draw.line([(rx - 1, 0), (rx - 1, h)], fill=(240, 245, 255), width=1)

    img.save(f"{OUTPUT_DIR}/railway/railway_track.png")
    print("Saved railway_track.png")

def make_hazard_platform():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), (45, 48, 52, 255))
    draw = ImageDraw.Draw(img)

    # Steel deck texture with diamond/grid pattern
    for x in range(0, w, 8):
        draw.line([(x, 0), (x, h)], fill=(38, 40, 44), width=1)
    for y in range(0, h, 8):
        draw.line([(0, y), (w, y)], fill=(38, 40, 44), width=1)

    # Angled caution hazard stripes border
    stripe_w = 16
    for i in range(-h, w + h, stripe_w * 2):
        draw.polygon([
            (i, 0), (i + stripe_w, 0),
            (i + stripe_w - 20, 20), (i - 20, 20)
        ], fill=(235, 195, 25))
        draw.polygon([
            (i, h - 20), (i + stripe_w, h - 20),
            (i + stripe_w + 20, h), (i + 20, h)
        ], fill=(235, 195, 25))

    # Dark border
    draw.rectangle([0, 0, w - 1, h - 1], outline=(20, 22, 24), width=3)
    img.save(f"{OUTPUT_DIR}/railway/hazard_platform.png")
    print("Saved hazard_platform.png")

# -------------------------------------------------------------
# 3. ENVIRONMENT & STRUCTURES (2.5D WITH HEIGHT)
# -------------------------------------------------------------
def make_concrete_wall_h():
    w, h = 256, 112
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Wall Top (Horizontal slab in 2.5D slant, y: 0..32)
    for y in range(32):
        col = 140 + int(y * 0.8) + np.random.randint(-6, 6)
        draw.line([(0, y), (w, y)], fill=(col, col - 4, col - 8, 255))
    # Top edge highlight
    draw.line([(0, 0), (w, 0)], fill=(195, 190, 180, 255), width=2)
    # Bevel divide
    draw.line([(0, 31), (w, 31)], fill=(70, 68, 65, 255), width=2)

    # Front Vertical Face (y: 32..104, 72px tall vertical height)
    for y in range(32, 104):
        # Grime gradient towards bottom
        factor = (y - 32) / 72.0
        col = int((115 - factor * 45) + np.random.randint(-8, 8))
        draw.line([(0, y), (w, y)], fill=(col, col - 3, col - 6, 255))

    # Concrete block seams (mortar joints)
    for bx in range(0, w, 64):
        draw.line([(bx, 32), (bx, 104)], fill=(45, 42, 40, 255), width=2)
    draw.line([(0, 68), (w, 68)], fill=(45, 42, 40, 255), width=2)

    # Mold / water drip stains
    for _ in range(16):
        dx = np.random.randint(10, w - 10)
        dh = np.random.randint(15, 45)
        for dy in range(dh):
            draw.line([(dx, 32 + dy), (dx + np.random.choice([-1, 0, 1]), 32 + dy + 1)],
                      fill=(35, 45, 30, 180), width=np.random.choice([2, 3]))

    # Ground shadow below wall (y: 104..112)
    for y in range(104, h):
        alpha = int(140 * (1.0 - (y - 104) / 8.0))
        draw.line([(0, y), (w, y)], fill=(10, 10, 12, alpha))

    img.save(f"{OUTPUT_DIR}/environment/concrete_wall_h.png")
    print("Saved concrete_wall_h.png")

def make_concrete_wall_v():
    w, h = 64, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Top Cap
    draw.rectangle([0, 0, w, 28], fill=(155, 150, 142, 255))
    draw.line([(0, 0), (w, 0)], fill=(195, 190, 180, 255), width=2)

    # Vertical Column front
    for x in range(w):
        col = 100 + int(math.sin(x * 0.1) * 15) + np.random.randint(-6, 6)
        draw.line([(x, 28), (x, h - 8)], fill=(col, col - 4, col - 7, 255))

    # Side shadow
    draw.line([(w - 1, 28), (w - 1, h - 8)], fill=(35, 35, 38, 255), width=3)

    # Base shadow
    for y in range(h - 8, h):
        alpha = int(140 * (1.0 - (y - (h - 8)) / 8.0))
        draw.line([(0, y), (w, y)], fill=(10, 10, 12, alpha))

    img.save(f"{OUTPUT_DIR}/environment/concrete_wall_v.png")
    print("Saved concrete_wall_v.png")

def make_bunker_building():
    w, h = 420, 320
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Concrete Bunker in 2.5D oblique slant
    # Rooftop (slanted slab, top y: 0..110)
    roof = [(20, 0), (w - 20, 0), (w - 10, 110), (10, 110)]
    draw.polygon(roof, fill=(80, 84, 88, 255))
    draw.line([(20, 0), (w - 20, 0)], fill=(125, 130, 135, 255), width=3)
    # Rooftop gravel noise & tar seams
    for y in range(10, 100, 25):
        draw.line([(20, y), (w - 20, y)], fill=(45, 48, 50, 255), width=2)

    # Front Vertical Wall (y: 110..290)
    wall_rect = [10, 110, w - 10, 290]
    for y in range(110, 290):
        shade = 110 - int((y - 110) * 0.25) + np.random.randint(-6, 6)
        draw.line([(10, y), (w - 10, y)], fill=(shade, shade - 3, shade - 6, 255))

    # Doorway in center (x: 180..240, y: 170..290)
    draw.rectangle([176, 166, 244, 290], fill=(40, 42, 45, 255)) # Door frame
    draw.rectangle([182, 172, 238, 290], fill=(12, 14, 16, 255)) # Dark interior
    # Open metal door angled out
    draw.polygon([(238, 172), (275, 185), (275, 290), (238, 290)], fill=(65, 52, 45, 255))
    draw.line([(238, 172), (275, 185)], fill=(120, 100, 80, 255), width=2)

    # Broken Windows on left and right
    for wx in [60, 310]:
        draw.rectangle([wx, 160, wx + 80, 220], fill=(42, 45, 48, 255)) # Frame
        draw.rectangle([wx + 4, 164, wx + 76, 216], fill=(15, 18, 22, 255)) # Shattered glass opening
        # Broken jagged glass shards
        draw.polygon([(wx + 4, 164), (wx + 30, 164), (wx + 15, 185)], fill=(140, 180, 200, 160))
        draw.polygon([(wx + 76, 216), (wx + 50, 216), (wx + 65, 195)], fill=(140, 180, 200, 160))

    # Exterior sodium floodlight fixture above doorway
    draw.rectangle([202, 140, 218, 150], fill=(50, 52, 55, 255))
    draw.ellipse([204, 146, 216, 158], fill=(240, 230, 170, 255))

    # Base ground shadow (y: 290..320)
    for y in range(290, h):
        alpha = int(160 * (1.0 - (y - 290) / 30.0))
        draw.line([(0, y), (w, y)], fill=(10, 10, 12, alpha))

    img.save(f"{OUTPUT_DIR}/environment/bunker_building.png")
    print("Saved bunker_building.png")

def make_chainlink_fence():
    # Horizontal fence
    w, h = 256, 80
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Steel posts every 64 pixels
    for px in range(16, w, 64):
        draw.line([(px, 10), (px, h - 8)], fill=(130, 135, 140, 255), width=5)
        draw.line([(px - 1, 10), (px - 1, h - 8)], fill=(185, 190, 195, 255), width=2)
        # Cap
        draw.ellipse([px - 4, 6, px + 4, 12], fill=(160, 165, 170, 255))

    # Top and bottom tension rails
    draw.line([(0, 14), (w, 14)], fill=(110, 115, 120, 255), width=3)
    draw.line([(0, h - 12), (w, h - 12)], fill=(90, 95, 100, 255), width=3)

    # Diamond mesh
    step = 8
    for x in range(-h, w + h, step * 2):
        draw.line([(x, 14), (x + (h - 26), h - 12)], fill=(160, 165, 170, 160), width=1)
        draw.line([(x + (h - 26), 14), (x, h - 12)], fill=(140, 145, 150, 160), width=1)

    # Barbed wire coiled along top
    for x in range(0, w, 12):
        draw.arc([x, 2, x + 12, 14], 0, math.pi, fill=(180, 185, 190, 255), width=2)
        draw.line([(x + 6, 2), (x + 8, 8)], fill=(220, 220, 225, 255), width=2)

    # Shadow
    for y in range(h - 8, h):
        alpha = int(120 * (1.0 - (y - (h - 8)) / 8.0))
        draw.line([(0, y), (w, y)], fill=(10, 10, 12, alpha))

    img.save(f"{OUTPUT_DIR}/environment/chainlink_fence_h.png")
    print("Saved chainlink_fence_h.png")

def make_car_wrecks():
    # Military Pickup Truck Wreck
    w, h = 220, 130
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Drop shadow
    draw.ellipse([10, 35, w - 10, h - 5], fill=(10, 10, 12, 170))

    # Truck Cab & Hood (2.5D isometric perspective, angled down-right)
    # Hood
    draw.polygon([(30, 45), (105, 20), (145, 38), (70, 65)], fill=(62, 68, 52, 255))
    # Windshield (cracked / dark)
    draw.polygon([(70, 65), (145, 38), (160, 58), (85, 85)], fill=(32, 42, 48, 255))
    draw.line([(80, 75), (130, 50)], fill=(160, 180, 190, 180), width=1)
    # Cab roof
    draw.polygon([(85, 85), (160, 58), (185, 68), (110, 95)], fill=(55, 60, 46, 255))
    # Truck bed (open cargo with rust)
    draw.polygon([(110, 95), (185, 68), (210, 80), (135, 108)], fill=(48, 42, 35, 255))
    # Side panels / doors
    draw.polygon([(30, 45), (70, 65), (135, 108), (135, 118), (25, 60)], fill=(45, 48, 38, 255))
    # Tires (deflated / dark rubber)
    draw.ellipse([35, 65, 60, 100], fill=(22, 22, 24, 255))
    draw.ellipse([40, 72, 55, 92], fill=(50, 45, 40, 255)) # Rusted rim
    draw.ellipse([125, 95, 150, 125], fill=(22, 22, 24, 255))

    # Rust streaks & soot
    for _ in range(8):
        rx = np.random.randint(40, 160)
        ry = np.random.randint(40, 90)
        draw.ellipse([rx, ry, rx + 14, ry + 8], fill=(110, 60, 32, 140))

    img.save(f"{OUTPUT_DIR}/environment/military_truck_wreck.png")
    print("Saved military_truck_wreck.png")

# -------------------------------------------------------------
# 4. PROPS (2.5D SHADED ISOMETRIC)
# -------------------------------------------------------------
def make_wooden_crate():
    w, h = 64, 72
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Cast shadow
    draw.ellipse([4, 48, 60, 70], fill=(12, 12, 14, 150))

    # 2.5D Crate: Top face (isometric rhombus), Left face, Right face
    # Points
    top_p = (32, 6)
    left_p = (4, 22)
    right_p = (60, 22)
    center_p = (32, 38)
    b_left = (4, 54)
    b_center = (32, 70)
    b_right = (60, 54)

    # Top face (light wood)
    draw.polygon([top_p, right_p, center_p, left_p], fill=(175, 138, 92, 255))
    # Left face (medium shaded wood)
    draw.polygon([left_p, center_p, b_center, b_left], fill=(132, 100, 62, 255))
    # Right face (dark shadow wood)
    draw.polygon([center_p, right_p, b_right, b_center], fill=(98, 72, 44, 255))

    # Corner brackets (iron rivets)
    draw.line([left_p, center_p], fill=(60, 48, 35), width=2)
    draw.line([center_p, right_p], fill=(60, 48, 35), width=2)
    draw.line([center_p, b_center], fill=(45, 35, 25), width=3)
    draw.line([left_p, b_left], fill=(45, 35, 25), width=2)
    draw.line([right_p, b_right], fill=(35, 28, 20), width=2)

    # Diagonal braces
    draw.line([left_p, b_center], fill=(85, 62, 38), width=3)
    draw.line([center_p, b_right], fill=(65, 48, 30), width=3)

    img.save(f"{OUTPUT_DIR}/props/crate_isometric.png")
    print("Saved crate_isometric.png")

def make_trash_bag():
    w, h = 54, 52
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Drop shadow
    draw.ellipse([4, 32, 50, 50], fill=(10, 10, 12, 140))

    # Black polyethylene bag folds
    draw.ellipse([6, 12, 48, 44], fill=(32, 34, 38, 255))
    draw.ellipse([12, 16, 42, 40], fill=(45, 48, 54, 255))
    # Tied knot at top
    draw.polygon([(22, 14), (27, 4), (32, 14)], fill=(65, 68, 75, 255))
    # Specular highlights (shiny wet plastic)
    draw.arc([16, 18, 38, 32], -math.pi * 0.8, -math.pi * 0.2, fill=(150, 160, 175, 180), width=2)
    draw.arc([20, 26, 34, 38], -math.pi * 0.8, -math.pi * 0.2, fill=(130, 140, 155, 160), width=2)

    img.save(f"{OUTPUT_DIR}/props/trash_bag.png")
    print("Saved trash_bag.png")

def make_oil_barrel():
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Shadow
    draw.ellipse([4, 46, 44, 62], fill=(10, 10, 12, 150))

    # Cylinder barrel body
    # Base ellipse
    draw.ellipse([6, 42, 42, 56], fill=(130, 25, 18, 255))
    # Body rectangle
    for x in range(6, 43):
        # Cylinder shading
        nx = (x - 6) / 36.0
        light = math.sin(nx * math.pi)
        col_r = int(70 + light * 135)
        col_g = int(18 + light * 25)
        col_b = int(12 + light * 18)
        draw.line([(x, 14), (x, 48)], fill=(col_r, col_g, col_b, 255))

    # Ribs
    for ry in [24, 36]:
        draw.arc([6, ry - 3, 42, ry + 5], 0, math.pi, fill=(60, 12, 8, 255), width=2)
        draw.arc([6, ry - 5, 42, ry + 3], 0, math.pi, fill=(220, 60, 45, 255), width=1)

    # Top Rim & Lid
    draw.ellipse([6, 6, 42, 20], fill=(110, 22, 16, 255))
    draw.ellipse([8, 8, 40, 18], fill=(155, 35, 25, 255))
    # Bunghole cap
    draw.ellipse([28, 11, 34, 15], fill=(45, 48, 52, 255))

    # Yellow Biohazard symbol in center
    draw.ellipse([20, 26, 28, 34], fill=(235, 195, 20, 240))
    draw.ellipse([22, 28, 26, 32], fill=(40, 12, 10, 240))

    img.save(f"{OUTPUT_DIR}/props/oil_barrel.png")
    print("Saved oil_barrel.png")

def make_pickups():
    # Medkit
    w, h = 36, 36
    med = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d_med = ImageDraw.Draw(med)
    d_med.ellipse([4, 22, 32, 34], fill=(10, 10, 12, 120)) # shadow
    d_med.rectangle([4, 8, 32, 28], fill=(55, 75, 48, 255)) # olive case
    d_med.rectangle([4, 8, 32, 11], fill=(85, 110, 75, 255)) # rim
    # Red cross
    d_med.ellipse([11, 12, 25, 26], fill=(240, 240, 245, 255))
    d_med.rectangle([16, 14, 20, 24], fill=(215, 35, 35, 255))
    d_med.rectangle([13, 17, 23, 21], fill=(215, 35, 35, 255))
    med.save(f"{OUTPUT_DIR}/props/pickup_health.png")

    # Ammo
    ammo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d_am = ImageDraw.Draw(ammo)
    d_am.ellipse([4, 22, 32, 34], fill=(10, 10, 12, 120))
    d_am.rectangle([5, 10, 31, 28], fill=(42, 45, 48, 255)) # steel ammo can
    d_am.rectangle([5, 10, 31, 13], fill=(68, 72, 78, 255)) # lid
    d_am.text((9, 15), "AMMO", fill=(235, 195, 25, 255))
    ammo.save(f"{OUTPUT_DIR}/props/pickup_ammo.png")
    print("Saved pickups.")

# -------------------------------------------------------------
# 5. DECALS (REALISTIC BLOOD)
# -------------------------------------------------------------
def make_blood_decals():
    for idx in range(1, 4):
        w, h = 128, 128
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        np.random.seed(200 + idx * 37)

        # Deep crimson coagulated blood with varying splatter radius
        center = (64, 64)
        for _ in range(8 + idx * 4):
            bx = 64 + np.random.randn() * (12 + idx * 4)
            by = 64 + np.random.randn() * (12 + idx * 4)
            rad = np.random.uniform(10, 24)
            darkness = np.random.randint(110, 160)
            draw.ellipse([bx - rad, by - rad, bx + rad, by + rad],
                         fill=(darkness, 8, 8, np.random.randint(180, 235)))

        # Outlying spray droplets
        for _ in range(35):
            angle = np.random.rand() * math.tau
            dist = np.random.uniform(20, 56)
            sx = center[0] + math.cos(angle) * dist
            sy = center[1] + math.sin(angle) * dist
            srad = np.random.uniform(1.5, 4.5)
            draw.ellipse([sx - srad, sy - srad, sx + srad, sy + srad],
                         fill=(np.random.randint(130, 185), 6, 6, 210))

        img = img.filter(ImageFilter.SMOOTH_MORE)
        img.save(f"{OUTPUT_DIR}/decals/blood_splat_{idx}.png")
    print("Saved blood splats.")

# -------------------------------------------------------------
# 6. LIGHTING COOKIES
# -------------------------------------------------------------
def make_lighting_cookies():
    # Flashlight Cone Cookie (512x512)
    w, h = 512, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    arr = np.zeros((h, w, 4), dtype=np.uint8)

    cx, cy = 30, 256 # Light source at left edge
    cone_angle = math.radians(52.0)
    max_range = 460.0

    y_grid, x_grid = np.ogrid[:h, :w]
    dx = x_grid - cx
    dy = y_grid - cy
    dist = np.sqrt(dx * dx + dy * dy)
    angle = np.abs(np.arctan2(dy, dx))

    # Mask within cone angle and max range
    in_range = (dist <= max_range) & (dx > 0)
    angle_falloff = np.clip(1.0 - (angle / (cone_angle * 0.5)), 0.0, 1.0)
    dist_falloff = np.clip(1.0 - (dist / max_range), 0.0, 1.0)

    # Hotspot near weapon muzzle
    hotspot = np.clip(1.0 - (dist / 140.0), 0.0, 1.0) * 1.5

    intensity = (angle_falloff ** 2) * (dist_falloff ** 1.3) + hotspot * (angle_falloff ** 3)
    intensity = np.clip(intensity, 0.0, 1.0)

    # Volumetric dust noise in beam
    noise = generate_noise(w, h, scale=24.0, octaves=3) * 0.18 + 0.9
    intensity = np.clip(intensity * noise, 0.0, 1.0)

    arr[..., 0] = 255 # R
    arr[..., 1] = 250 # G
    arr[..., 2] = 235 # B
    arr[..., 3] = (intensity * 255).astype(np.uint8) # Alpha

    Image.fromarray(arr, mode="RGBA").save(f"{OUTPUT_DIR}/lighting/flashlight_cookie.png")

    # Radial Point Light Cookie (256x256)
    pw, ph = 256, 256
    py, px = np.ogrid[:ph, :pw]
    pdist = np.sqrt((px - 128) ** 2 + (py - 128) ** 2)
    pfalloff = np.clip(1.0 - (pdist / 128.0), 0.0, 1.0) ** 1.8

    parr = np.zeros((ph, pw, 4), dtype=np.uint8)
    parr[..., 0] = 255
    parr[..., 1] = 245
    parr[..., 2] = 220
    parr[..., 3] = (pfalloff * 255).astype(np.uint8)

    Image.fromarray(parr, mode="RGBA").save(f"{OUTPUT_DIR}/lighting/point_light_cookie.png")
    print("Saved lighting cookies.")

# -------------------------------------------------------------
# 7. CHARACTERS (8-DIRECTIONAL 2.5D PRE-RENDERED SPRITE SHEETS)
# -------------------------------------------------------------
def render_soldier_frame(angle_rad, size=72):
    """Render a standing 2.5D soldier with boots, camo, tactical vest, helmet, rifle."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2

    # Drop shadow
    draw.ellipse([cx - 16, cy + 18, cx + 16, cy + 28], fill=(10, 10, 12, 130))

    # Angle orientation
    # 0 = Facing East (Right), PI/2 = South (Front), PI = West (Left), -PI/2 = North (Back)
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)

    # 1. Legs & Combat Boots (standing in 2.5D)
    boot_col = (25, 26, 28)
    pants_col = (48, 56, 44) # Camo olive
    draw.rectangle([cx - 10, cy + 8, cx - 2, cy + 22], fill=pants_col)
    draw.rectangle([cx + 2, cy + 8, cx + 10, cy + 22], fill=pants_col)
    draw.rectangle([cx - 11, cy + 20, cx - 1, cy + 25], fill=boot_col)
    draw.rectangle([cx + 1, cy + 20, cx + 11, cy + 25], fill=boot_col)

    # 2. Torso / Body Armor
    vest_col = (28, 32, 38)
    draw.ellipse([cx - 13, cy - 8, cx + 13, cy + 12], fill=vest_col)
    draw.rectangle([cx - 9, cy - 6, cx + 9, cy + 8], fill=(36, 42, 50)) # Kevlar plate

    # 3. Shoulders
    sh_offset_x = -sin_a * 10
    sh_offset_y = cos_a * 6
    draw.circle((cx - sh_offset_x, cy - 2 - sh_offset_y), 6, fill=vest_col)
    draw.circle((cx + sh_offset_x, cy - 2 + sh_offset_y), 6, fill=vest_col)

    # 4. Weapon (Assault rifle extending forward along aim vector)
    gun_len = 24
    gx = cx + cos_a * 8
    gy = cy + sin_a * 6 - 2
    g_end_x = gx + cos_a * gun_len
    g_end_y = gy + sin_a * gun_len
    draw.line([(gx, gy), (g_end_x, g_end_y)], fill=(18, 20, 22), width=4)
    draw.line([(gx + cos_a * 6, gy + sin_a * 6), (gx + cos_a * 18, gy + sin_a * 18)], fill=(65, 70, 75), width=2)
    # Hands holding weapon
    draw.circle((gx + cos_a * 7, gy + sin_a * 7), 3, fill=(195, 160, 130))
    draw.circle((gx + cos_a * 15, gy + sin_a * 15), 3, fill=(195, 160, 130))

    # 5. Helmet & Head (facing angle)
    head_y = cy - 8
    draw.circle((cx, head_y), 8, fill=(35, 42, 34)) # Camo helmet
    draw.ellipse([cx - 8, head_y - 2, cx + 8, head_y + 7], fill=(28, 34, 28))
    # Visor / Face
    if sin_a > -0.3: # Visible when not looking directly away
        vx = cx + cos_a * 5
        vy = head_y + sin_a * 3 + 2
        draw.ellipse([vx - 4, vy - 2, vx + 4, vy + 3], fill=(30, 140, 200)) # Tactical goggles

    return img

def render_zombie_frame(angle_rad, z_type="regular", size=72):
    """Render 2.5D infected walker, dog, or heavy mutant."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)

    # Shadow
    draw.ellipse([cx - 15, cy + 16, cx + 15, cy + 26], fill=(10, 10, 12, 130))

    if z_type == "regular":
        # Rotting green-grey skin, tattered blue jeans, bloody torso
        skin_col = (95, 120, 82)
        shirt_col = (55, 65, 80)
        blood_col = (140, 20, 20)

        # Legs
        draw.rectangle([cx - 8, cy + 8, cx - 2, cy + 20], fill=(42, 50, 68))
        draw.rectangle([cx + 2, cy + 8, cx + 8, cy + 20], fill=(35, 42, 58))

        # Torso
        draw.ellipse([cx - 12, cy - 6, cx + 12, cy + 12], fill=shirt_col)
        # Blood stain on chest
        draw.ellipse([cx - 4, cy - 2, cx + 5, cy + 7], fill=blood_col)

        # Arms reaching forward aggressively
        for side in [-8, 8]:
            ax = cx + side * (-sin_a) + cos_a * 4
            ay = cy + side * (cos_a) + sin_a * 4
            a_end_x = ax + cos_a * 18
            a_end_y = ay + sin_a * 18
            draw.line([(ax, ay), (a_end_x, a_end_y)], fill=skin_col, width=4)
            draw.circle((a_end_x, a_end_y), 3, fill=(120, 30, 30)) # Bloody clawed hands

        # Decayed Head
        head_y = cy - 8
        draw.circle((cx, head_y), 8, fill=skin_col)
        if sin_a > -0.4:
            ex = cx + cos_a * 4
            ey = head_y + sin_a * 3
            draw.circle((ex, ey), 2, fill=(240, 25, 20)) # Red glowing eye

    elif z_type == "dog":
        # Feral quad predator: elongated spine, exposed ribs, snarling jaws
        hide_col = (115, 60, 42)
        bone_col = (180, 175, 160)

        # Canine body elongated along aim angle
        bx1 = cx - cos_a * 14
        by1 = cy - sin_a * 14
        bx2 = cx + cos_a * 14
        by2 = cy + sin_a * 14
        draw.line([(bx1, by1), (bx2, by2)], fill=hide_col, width=12)

        # Exposed ribs
        for r_off in [-4, 0, 4]:
            rx = cx + cos_a * r_off
            ry = cy + sin_a * r_off
            draw.line([(rx - sin_a * 5, ry + cos_a * 5), (rx + sin_a * 5, ry - cos_a * 5)], fill=bone_col, width=2)

        # Snout & Fangs forward
        snout_x = cx + cos_a * 22
        snout_y = cy + sin_a * 22
        draw.circle((snout_x, snout_y), 6, fill=hide_col)
        draw.circle((snout_x + cos_a * 3, snout_y + sin_a * 3), 2, fill=(245, 245, 240)) # Fangs
        draw.circle((snout_x, snout_y - 2), 2, fill=(230, 30, 20)) # Eye

    elif z_type == "heavy":
        # Massive mutant brute (size=96)
        skin_col = (110, 95, 88)
        armor_col = (45, 45, 48)

        # Legs
        draw.rectangle([cx - 14, cy + 12, cx - 2, cy + 28], fill=armor_col)
        draw.rectangle([cx + 2, cy + 12, cx + 14, cy + 28], fill=armor_col)

        # Massive hulking torso
        draw.ellipse([cx - 22, cy - 14, cx + 22, cy + 16], fill=skin_col)
        draw.rectangle([cx - 16, cy - 10, cx + 16, cy + 12], fill=armor_col) # Iron scrap plate

        # Huge shoulders & fists
        for side in [-18, 18]:
            fx = cx + side * (-sin_a) + cos_a * 8
            fy = cy + side * (cos_a) + sin_a * 8
            draw.circle((fx, fy), 11, fill=skin_col)
            draw.line([(fx, fy), (fx + cos_a * 18, fy + sin_a * 18)], fill=skin_col, width=8)

        # Pinhead mutant skull
        draw.circle((cx + cos_a * 5, cy - 14 + sin_a * 3), 10, fill=skin_col)
        draw.circle((cx + cos_a * 8, cy - 14 + sin_a * 3), 3, fill=(255, 40, 20))

    return img

def make_character_sheets():
    # 8-Direction Sprite Sheet: [E, SE, S, SW, W, NW, N, NE]
    angles = [0, math.pi / 4, math.pi / 2, 3 * math.pi / 4, math.pi, -3 * math.pi / 4, -math.pi / 2, -math.pi / 4]

    # 1. Soldier
    soldier_sheet = Image.new("RGBA", (72 * 8, 72), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_soldier_frame(a, size=72)
        soldier_sheet.paste(f, (i * 72, 0))
    soldier_sheet.save(f"{OUTPUT_DIR}/characters/soldier_8dir.png")

    # 2. Regular Zombie
    zombie_sheet = Image.new("RGBA", (72 * 8, 72), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_zombie_frame(a, z_type="regular", size=72)
        zombie_sheet.paste(f, (i * 72, 0))
    zombie_sheet.save(f"{OUTPUT_DIR}/characters/zombie_regular_8dir.png")

    # 3. Infected Dog
    dog_sheet = Image.new("RGBA", (72 * 8, 72), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_zombie_frame(a, z_type="dog", size=72)
        dog_sheet.paste(f, (i * 72, 0))
    dog_sheet.save(f"{OUTPUT_DIR}/characters/zombie_dog_8dir.png")

    # 4. Heavy Mutant Brute (96x96 per frame)
    heavy_sheet = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        f = render_zombie_frame(a, z_type="heavy", size=96)
        heavy_sheet.paste(f, (i * 96, 0))
    heavy_sheet.save(f"{OUTPUT_DIR}/characters/zombie_heavy_8dir.png")

    print("Saved all character sprite sheets.")

def main():
    ensure_dirs()
    make_dirt_terrain()
    make_cracked_asphalt()
    make_dead_grass()
    make_railway_track()
    make_hazard_platform()
    make_concrete_wall_h()
    make_concrete_wall_v()
    make_bunker_building()
    make_chainlink_fence()
    make_car_wrecks()
    make_wooden_crate()
    make_trash_bag()
    make_oil_barrel()
    make_pickups()
    make_blood_decals()
    make_lighting_cookies()
    make_character_sheets()
    print("ALL TEXTURES GENERATED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
