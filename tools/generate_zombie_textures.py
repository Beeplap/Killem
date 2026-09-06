import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

os.makedirs("assets/textures/characters", exist_ok=True)
os.makedirs("assets/textures/decals", exist_ok=True)

# 1. Zombie Decayed Flesh (256x256)
def make_zombie_flesh_pbr():
    w, h = 256, 256
    np.random.seed(101)
    # Sickly grey-green base
    base = np.random.normal(120, 15, (h, w)).clip(80, 160).astype(np.uint8)
    r = (base * 0.72).clip(0, 255).astype(np.uint8)
    g = (base * 0.85).clip(0, 255).astype(np.uint8)
    b = (base * 0.68).clip(0, 255).astype(np.uint8)
    img = Image.fromarray(np.stack([r, g, b], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)
    
    # Blood splotches and decaying veins
    for _ in range(40):
        vx = np.random.randint(0, w)
        vy = np.random.randint(0, h)
        vr = np.random.randint(2, 6)
        draw.ellipse([vx - vr, vy - vr, vx + vr, vy + vr], fill=(95, 25, 25))
    
    for _ in range(15):
        cx = np.random.randint(0, w)
        cy = np.random.randint(0, h)
        for _ in range(12):
            nx = cx + np.random.randint(-4, 5)
            ny = cy + np.random.randint(-4, 5)
            draw.line([(cx, cy), (nx, ny)], fill=(35, 55, 45), width=1)
            cx, ny = nx, ny
            
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save("assets/textures/characters/zombie_flesh_pbr.png")
    
    # Normal map
    n_arr = np.zeros((h, w, 3), dtype=np.uint8)
    n_arr[:, :] = [128, 128, 255]
    for _ in range(80):
        bx = np.random.randint(2, w - 3)
        by = np.random.randint(2, h - 3)
        n_arr[by-1:by+2, bx-1:bx+2] = [145, 120, 230]
    Image.fromarray(n_arr).save("assets/textures/characters/zombie_flesh_pbr_n.png")
    print("Saved zombie_flesh_pbr.png")

# 2. Plague Hound Mangy Hide (256x256)
def make_hound_hide_pbr():
    w, h = 256, 256
    np.random.seed(102)
    # Dark charred charcoal/maroon
    base = np.random.normal(70, 18, (h, w)).clip(40, 110).astype(np.uint8)
    r = (base * 1.1).clip(0, 255).astype(np.uint8)
    g = (base * 0.7).clip(0, 255).astype(np.uint8)
    b = (base * 0.65).clip(0, 255).astype(np.uint8)
    img = Image.fromarray(np.stack([r, g, b], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)
    
    # Raw infected lesions
    for _ in range(35):
        lx = np.random.randint(0, w)
        ly = np.random.randint(0, h)
        lr = np.random.randint(3, 8)
        draw.ellipse([lx - lr, ly - lr, lx + lr, ly + lr], fill=(135, 30, 25))
        draw.ellipse([lx - lr//2, ly - lr//2, lx + lr//2, ly + lr//2], fill=(180, 50, 40))
        
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save("assets/textures/characters/hound_hide_pbr.png")
    
    n_arr = np.zeros((h, w, 3), dtype=np.uint8)
    n_arr[:, :] = [128, 128, 255]
    Image.fromarray(n_arr).save("assets/textures/characters/hound_hide_pbr_n.png")
    print("Saved hound_hide_pbr.png")

# 3. Super Mutant Armored Hide (256x256)
def make_mutant_hide_pbr():
    w, h = 256, 256
    np.random.seed(103)
    # Heavy stone/chitin grey-slate
    base = np.random.normal(85, 12, (h, w)).clip(55, 125).astype(np.uint8)
    r = (base * 0.85).clip(0, 255).astype(np.uint8)
    g = (base * 0.90).clip(0, 255).astype(np.uint8)
    b = (base * 0.80).clip(0, 255).astype(np.uint8)
    img = Image.fromarray(np.stack([r, g, b], axis=-1), mode="RGB")
    draw = ImageDraw.Draw(img)
    
    # Armored carapace plates & fissures
    for step in range(0, w, 32):
        draw.line([(step, 0), (step, h)], fill=(35, 40, 38), width=3)
        draw.line([(0, step), (w, step)], fill=(35, 40, 38), width=3)
        draw.line([(step + 2, 0), (step + 2, h)], fill=(130, 135, 130), width=1)
        
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.save("assets/textures/characters/mutant_hide_pbr.png")
    
    n_arr = np.zeros((h, w, 3), dtype=np.uint8)
    n_arr[:, :] = [128, 128, 255]
    for step in range(0, w, 32):
        if step > 2 and step < w - 2:
            n_arr[:, step-1] = [170, 128, 230]
            n_arr[:, step] = [80, 128, 230]
    Image.fromarray(n_arr).save("assets/textures/characters/mutant_hide_pbr_n.png")
    print("Saved mutant_hide_pbr.png")

# 4. Acid Pustule Bioluminescent Skin (256x256)
def make_acid_pustule_pbr():
    w, h = 256, 256
    np.random.seed(104)
    # Putrid yellowish-green mottled base
    img = Image.new("RGB", (w, h), (75, 100, 35))
    draw = ImageDraw.Draw(img)
    
    # Swollen pustule clusters
    for _ in range(25):
        px = np.random.randint(15, w - 15)
        py = np.random.randint(15, h - 15)
        pr = np.random.randint(10, 22)
        # Gradient glowing pustule
        for r in range(pr, 2, -3):
            fade = 1.0 - (r / pr)
            g_col = int(140 + fade * 115)
            r_col = int(80 + fade * 90)
            b_col = int(20 + fade * 30)
            draw.ellipse([px - r, py - r, px + r, py + r], fill=(r_col, g_col, b_col))
            
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    img.save("assets/textures/characters/acid_pustule_pbr.png")
    
    n_arr = np.zeros((h, w, 3), dtype=np.uint8)
    n_arr[:, :] = [128, 128, 255]
    Image.fromarray(n_arr).save("assets/textures/characters/acid_pustule_pbr_n.png")
    print("Saved acid_pustule_pbr.png")

# 5. Toxic Pool Decal (256x256 RGBA)
def make_toxic_pool_decal():
    w, h = 256, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = w // 2, h // 2
    # Irregular bubbling pool
    np.random.seed(105)
    points = []
    num_pts = 32
    for i in range(num_pts):
        angle = (i / num_pts) * math.tau
        rad = np.random.uniform(75, 110)
        points.append((cx + math.cos(angle) * rad, cy + math.sin(angle) * rad))
        
    draw.polygon(points, fill=(60, 220, 40, 190))
    
    # Center deeper core
    core_pts = [(cx + (px - cx) * 0.65, cy + (py - cy) * 0.65) for px, py in points]
    draw.polygon(core_pts, fill=(120, 255, 60, 225))
    
    # Acid bubbles
    for _ in range(45):
        bx = cx + np.random.randint(-70, 70)
        by = cy + np.random.randint(-70, 70)
        br = np.random.randint(3, 8)
        draw.ellipse([bx - br, by - br, bx + br, by + br], fill=(210, 255, 120, 240), outline=(30, 120, 20, 200))
        
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    img.save("assets/textures/decals/toxic_pool.png")
    print("Saved toxic_pool.png")

if __name__ == "__main__":
    make_zombie_flesh_pbr()
    make_hound_hide_pbr()
    make_mutant_hide_pbr()
    make_acid_pustule_pbr()
    make_toxic_pool_decal()
