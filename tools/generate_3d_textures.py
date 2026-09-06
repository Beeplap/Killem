import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

os.makedirs("assets/textures/ground", exist_ok=True)
os.makedirs("assets/textures/environment", exist_ok=True)
os.makedirs("assets/textures/props", exist_ok=True)
os.makedirs("assets/textures/decals", exist_ok=True)

# 1. Asphalt Road with Highway Markings (512x512)
def make_asphalt_road_pbr():
    w, h = 512, 512
    # Base weathered asphalt
    base = np.random.normal(110, 10, (h, w)).clip(85, 140).astype(np.uint8)
    img = Image.fromarray(np.stack([base, (base * 1.02).clip(0, 255).astype(np.uint8), (base * 1.05).clip(0, 255).astype(np.uint8)], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)
    
    # Fine road aggregate gravel
    for _ in range(1200):
        gx = np.random.randint(0, w)
        gy = np.random.randint(0, h)
        gr = np.random.randint(1, 3)
        gs = np.random.randint(130, 180)
        draw.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=(gs, gs, gs))
    
    # Road cracks
    np.random.seed(42)
    for _ in range(14):
        cx = np.random.randint(20, w - 20)
        cy = np.random.randint(20, h - 20)
        angle = np.random.rand() * math.tau
        steps = np.random.randint(20, 55)
        for _ in range(steps):
            nx = cx + math.cos(angle) * 3.5 + np.random.randn() * 1.0
            ny = cy + math.sin(angle) * 3.5 + np.random.randn() * 1.0
            draw.line([(cx + 1, cy + 1), (nx + 1, ny + 1)], fill=(160, 165, 175), width=1) # Highlight
            draw.line([(cx, cy), (nx, ny)], fill=(30, 32, 35), width=2) # Fissure
            if np.random.rand() < 0.2:
                angle += np.random.uniform(-0.7, 0.7)
            cx, ny = nx, ny
    
    # Painted Highway Markings:
    # Double yellow center lines (running vertically along center x = 256)
    yellow = (235, 195, 45)
    draw.line([(251, 0), (251, h)], fill=yellow, width=5)
    draw.line([(261, 0), (261, h)], fill=yellow, width=5)
    
    # Solid white edge lines (x = 35 and x = 475)
    white = (225, 230, 235)
    draw.line([(35, 0), (35, h)], fill=white, width=6)
    draw.line([(475, 0), (475, h)], fill=white, width=6)
    
    # Subtle weathering on painted lines
    for _ in range(150):
        wx = np.random.choice([251, 261, 35, 475]) + np.random.randint(-3, 4)
        wy = np.random.randint(0, h)
        draw.point((wx, wy), fill=(95, 100, 105))
        
    img.save("assets/textures/ground/asphalt_road_pbr.png")
    print("Saved asphalt_road_pbr.png")

# 2. Chainlink Wire Mesh with Alpha Cutout (256x256)
def make_chainlink_wire():
    w, h = 256, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    spacing = 16
    steel_col = (190, 195, 205, 255)
    steel_dark = (90, 95, 105, 255)
    
    # Diagonals / diamond weave
    for i in range(-w, w * 2, spacing):
        draw.line([(i, 0), (i + h, h)], fill=steel_dark, width=3)
        draw.line([(i, 0), (i + h, h)], fill=steel_col, width=2)
        draw.line([(i + h, 0), (i, h)], fill=steel_dark, width=3)
        draw.line([(i + h, 0), (i, h)], fill=steel_col, width=2)
        
    img.save("assets/textures/environment/chainlink_wire.png")
    print("Saved chainlink_wire.png")

# 3. Decal: Oil Slick (256x256 RGBA)
def make_oil_slick():
    w, h = 256, 256
    cx, cy = w // 2, h // 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    np.random.seed(123)
    # Irregular puddle blobs
    for rad in range(95, 15, -4):
        alpha = int(180 * (rad / 95.0))
        pts = []
        for a in np.linspace(0, math.tau, 28, endpoint=False):
            dist = rad + np.random.uniform(-10, 10) * (rad / 95.0)
            pts.append((cx + math.cos(a) * dist, cy + math.sin(a) * (dist * 0.75)))
        draw.polygon(pts, fill=(12, 14, 18, alpha))
        
    # Iridescent film rings
    draw.arc([cx - 45, cy - 30, cx + 45, cy + 30], 0, 360, fill=(35, 65, 85, 90), width=3)
    draw.arc([cx - 30, cy - 20, cx + 30, cy + 20], 0, 360, fill=(85, 45, 75, 80), width=2)
    
    img = img.filter(ImageFilter.GaussianBlur(3.0))
    img.save("assets/textures/decals/oil_slick.png")
    print("Saved oil_slick.png")

# 4. Decal: Blast Scorch (256x256 RGBA)
def make_blast_scorch():
    w, h = 256, 256
    cx, cy = w // 2, h // 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    np.random.seed(456)
    # Central charred black crater
    for rad in range(110, 5, -5):
        alpha = int(220 * (1.0 - (rad / 110.0)**1.5))
        pts = []
        for a in np.linspace(0, math.tau, 32, endpoint=False):
            r = rad + np.random.uniform(-14, 14)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        draw.polygon(pts, fill=(10, 10, 12, alpha))
        
    # Radial scorch rays / shrapnel streaks
    for _ in range(48):
        angle = np.random.rand() * math.tau
        dist1 = np.random.uniform(20, 60)
        dist2 = np.random.uniform(80, 122)
        p1 = (cx + math.cos(angle) * dist1, cy + math.sin(angle) * dist1)
        p2 = (cx + math.cos(angle) * dist2, cy + math.sin(angle) * dist2)
        draw.line([p1, p2], fill=(15, 15, 18, np.random.randint(60, 160)), width=np.random.randint(1, 4))
        
    img = img.filter(ImageFilter.GaussianBlur(2.5))
    img.save("assets/textures/decals/blast_scorch.png")
    print("Saved blast_scorch.png")

# 5. Concrete Wall PBR Texture (512x512)
def make_concrete_wall_pbr():
    w, h = 512, 512
    base = np.random.normal(145, 12, (h, w)).clip(115, 180).astype(np.uint8)
    img = Image.fromarray(np.stack([base, (base * 0.98).astype(np.uint8), (base * 0.96).astype(np.uint8)], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)
    
    # Concrete formwork panel seam lines (horizontal and vertical)
    draw.line([(0, 256), (w, 256)], fill=(60, 58, 55), width=2)
    draw.line([(0, 257), (w, 257)], fill=(185, 180, 175), width=1) # Seam highlight
    draw.line([(256, 0), (256, h)], fill=(60, 58, 55), width=2)
    draw.line([(257, 0), (257, h)], fill=(185, 180, 175), width=1)
    
    # Formwork tie holes
    for hx in [64, 192, 320, 448]:
        for hy in [64, 192, 320, 448]:
            draw.ellipse([hx - 4, hy - 4, hx + 4, hy + 4], fill=(50, 48, 45))
            draw.ellipse([hx - 3, hy - 3, hx + 3, hy + 3], fill=(30, 28, 26))
            # Water drip stain below hole
            draw.line([(hx, hy + 4), (hx, hy + 28)], fill=(80, 75, 70), width=2)
            
    img.save("assets/textures/environment/concrete_wall_pbr.png")
    print("Saved concrete_wall_pbr.png")

# 6. Metal Barrel Texture (256x256)
def make_metal_barrel_pbr():
    w, h = 256, 256
    # Corrugated hazard red painted steel
    img = Image.new("RGB", (w, h), (175, 38, 28))
    draw = ImageDraw.Draw(img)
    
    # Horizontal steel rolling hoops / ribs
    for y in [45, 110, 145, 210]:
        draw.line([(0, y - 2), (w, y - 2)], fill=(225, 80, 70), width=2)
        draw.line([(0, y), (w, y)], fill=(85, 18, 14), width=3)
        draw.line([(0, y + 3), (w, y + 3)], fill=(210, 65, 55), width=2)
        
    # Yellow hazard band around center
    draw.rectangle([0, 118, w, 138], fill=(225, 180, 25))
    draw.line([(0, 118), (w, 118)], fill=(75, 60, 10), width=1)
    draw.line([(0, 138), (w, 138)], fill=(75, 60, 10), width=1)
    
    # Rust chipping and scratches
    np.random.seed(88)
    for _ in range(250):
        rx = np.random.randint(0, w)
        ry = np.random.randint(0, h)
        import random
        rc = random.choice([(70, 40, 25), (45, 35, 30), (120, 70, 40)])
        draw.ellipse([rx - 1, ry - 1, rx + 2, ry + 2], fill=rc)
        
    img.save("assets/textures/props/metal_barrel_pbr.png")
    print("Saved metal_barrel_pbr.png")

# 7. 3D Billboard Grass Tuft (128x128 RGBA)
def make_grass_tuft():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    np.random.seed(99)
    cx, cy = w // 2, h - 6
    for _ in range(50):
        length = np.random.uniform(35, 85)
        angle = np.random.uniform(-math.pi * 0.85, -math.pi * 0.15)
        curve = np.random.uniform(-14, 14)
        ex = cx + math.cos(angle) * length + curve
        ey = cy + math.sin(angle) * length
        mx = (cx + ex) / 2 + curve * 0.6
        my = (cy + ey) / 2
        
        c_r = np.random.randint(140, 195)
        c_g = np.random.randint(130, 180)
        c_b = np.random.randint(65, 100)
        draw.line([(cx + np.random.randint(-8, 8), cy), (mx, my), (ex, ey)], fill=(c_r, c_g, c_b, 255), width=np.random.choice([1, 2]))
        
    img.save("assets/textures/environment/grass_tuft.png")
    print("Saved grass_tuft.png")

# 8. Wooden Pallet Slats PBR (256x256)
def make_wooden_pallet_pbr():
    w, h = 256, 256
    img = Image.new("RGB", (w, h), (145, 115, 80))
    draw = ImageDraw.Draw(img)
    
    # Wood plank grain
    np.random.seed(77)
    for y in range(h):
        shade = int(140 + 20 * math.sin(y * 0.15) + np.random.randint(-15, 15))
        shade = max(80, min(210, shade))
        r = int(shade * 1.05)
        g = int(shade * 0.82)
        b = int(shade * 0.55)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    
    # Slat seams and cracks
    for sx in [0, 64, 128, 192, 255]:
        draw.line([(sx, 0), (sx, h)], fill=(40, 30, 20), width=2)
    
    # Nail heads
    for nx in [32, 96, 160, 224]:
        for ny in [20, 128, 236]:
            draw.ellipse([nx - 3, ny - 3, nx + 3, ny + 3], fill=(50, 52, 55))
            draw.ellipse([nx - 2, ny - 2, nx + 2, ny + 2], fill=(90, 95, 100))
    
    img.save("assets/textures/props/wooden_pallet_pbr.png")
    
    # Normal map
    n_arr = np.zeros((h, w, 3), dtype=np.uint8)
    n_arr[:, :] = [128, 128, 255]
    for sx in [0, 64, 128, 192, 255]:
        if sx > 1 and sx < w - 2:
            n_arr[:, sx - 1] = [170, 128, 230]
            n_arr[:, sx] = [80, 128, 230]
    Image.fromarray(n_arr).save("assets/textures/props/wooden_pallet_pbr_n.png")
    print("Saved wooden_pallet_pbr.png and normal map")

if __name__ == "__main__":
    make_asphalt_road_pbr()
    make_chainlink_wire()
    make_oil_slick()
    make_blast_scorch()
    make_concrete_wall_pbr()
    make_metal_barrel_pbr()
    make_grass_tuft()
    make_wooden_pallet_pbr()
