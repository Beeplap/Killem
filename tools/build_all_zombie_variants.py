import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageOps
import sys
sys.path.insert(0, os.getcwd())
from tools.generate_normal_maps import generate_normal_map

OUTPUT_DIR = "assets/textures/characters"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. PBR TEXTURE GENERATION FOR 3D MODELS
# -------------------------------------------------------------

def build_pbr_textures():
    w, h = 512, 512
    np.random.seed(42)

    # A. Decaying Zombie Flesh (Pale greyish-green with crimson lacerations & necrotic veins)
    base_skin = np.random.normal(135, 12, (h, w)).clip(90, 175).astype(np.uint8)
    r = (base_skin * 0.78).clip(0, 255).astype(np.uint8)
    g = (base_skin * 0.88).clip(0, 255).astype(np.uint8)
    b = (base_skin * 0.76).clip(0, 255).astype(np.uint8)
    flesh_img = Image.fromarray(np.stack([r, g, b], axis=-1), mode="RGB")
    draw_flesh = ImageDraw.Draw(flesh_img)
    
    # Blood wounds and necrotic splotches
    for _ in range(80):
        vx = np.random.randint(0, w)
        vy = np.random.randint(0, h)
        vr = np.random.randint(4, 16)
        draw_flesh.ellipse([vx - vr, vy - vr, vx + vr, vy + vr], fill=(130, 22, 22))
        draw_flesh.ellipse([vx - vr//2, vy - vr//2, vx + vr//2, vy + vr//2], fill=(85, 12, 12))
    # Bruised blue/purple veins
    for _ in range(30):
        cx, cy = np.random.randint(0, w), np.random.randint(0, h)
        for _ in range(16):
            nx = cx + np.random.randint(-6, 7)
            ny = cy + np.random.randint(-6, 7)
            draw_flesh.line([(cx, cy), (nx, ny)], fill=(45, 55, 65), width=2)
            cx, ny = nx, ny
    flesh_img = flesh_img.filter(ImageFilter.GaussianBlur(0.8))
    flesh_img.save(f"{OUTPUT_DIR}/zombie_flesh_pbr.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_flesh_pbr.png", f"{OUTPUT_DIR}/zombie_flesh_pbr_n.png", strength=2.8)

    # B. Rotting Hound Flesh & Raw Muscle (Resident Evil Cerberus style: crimson muscle striations)
    base_muscle = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        stripes = np.sin(y * 0.25) * 20.0 + np.sin(y * 0.08) * 35.0
        val_r = np.clip(160 + stripes + np.random.normal(0, 10, w), 90, 220).astype(np.uint8)
        val_g = np.clip(30 + stripes * 0.2 + np.random.normal(0, 5, w), 10, 60).astype(np.uint8)
        val_b = np.clip(25 + stripes * 0.15 + np.random.normal(0, 4, w), 10, 50).astype(np.uint8)
        base_muscle[y, :, 0] = val_r
        base_muscle[y, :, 1] = val_g
        base_muscle[y, :, 2] = val_b
    hound_flesh = Image.fromarray(base_muscle, mode="RGB")
    draw_hf = ImageDraw.Draw(hound_flesh)
    # Fatty white connective tissue and dark clotted blood
    for _ in range(60):
        x1, y1 = np.random.randint(0, w), np.random.randint(0, h)
        x2 = x1 + np.random.randint(-30, 30)
        y2 = y1 + np.random.randint(-10, 10)
        draw_hf.line([(x1, y1), (x2, y2)], fill=(210, 185, 175), width=1) # fascia
        draw_hf.line([(x1 + 2, y1 + 2), (x2 + 2, y2 + 2)], fill=(65, 8, 8), width=3) # dark clot
    hound_flesh = hound_flesh.filter(ImageFilter.GaussianBlur(0.6))
    hound_flesh.save(f"{OUTPUT_DIR}/hound_flesh_pbr.png")
    generate_normal_map(f"{OUTPUT_DIR}/hound_flesh_pbr.png", f"{OUTPUT_DIR}/hound_flesh_pbr_n.png", strength=3.2)

    # C. Mangy Hound Hide (Dark charred fur with bald patches)
    hide_arr = np.zeros((h, w, 3), dtype=np.uint8)
    fur_base = np.random.normal(32, 8, (h, w)).clip(15, 65).astype(np.uint8)
    hide_arr[:, :, 0] = fur_base
    hide_arr[:, :, 1] = fur_base
    hide_arr[:, :, 2] = (fur_base * 0.9).astype(np.uint8)
    hound_hide = Image.fromarray(hide_arr, mode="RGB")
    draw_hide = ImageDraw.Draw(hound_hide)
    # Mange patches showing raw flesh underneath
    for _ in range(35):
        lx, ly = np.random.randint(0, w), np.random.randint(0, h)
        lr = np.random.randint(12, 35)
        draw_hide.ellipse([lx - lr, ly - lr, lx + lr, ly + lr], fill=(145, 28, 22))
        draw_hide.ellipse([lx - lr//2, ly - lr//2, lx + lr//2, ly + lr//2], fill=(95, 12, 10))
    hound_hide = hound_hide.filter(ImageFilter.GaussianBlur(0.7))
    hound_hide.save(f"{OUTPUT_DIR}/hound_hide_pbr.png")
    generate_normal_map(f"{OUTPUT_DIR}/hound_hide_pbr.png", f"{OUTPUT_DIR}/hound_hide_pbr_n.png", strength=2.5)

    # D. Tattered Denim (Garwalfs tattered blue jeans texture)
    denim_arr = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            twill = 18 if (x + y) % 4 == 0 else 0
            denim_arr[y, x, 0] = np.clip(45 + twill + np.random.randint(-4, 5), 25, 80)
            denim_arr[y, x, 1] = np.clip(68 + twill + np.random.randint(-5, 6), 40, 110)
            denim_arr[y, x, 2] = np.clip(115 + twill + np.random.randint(-6, 7), 75, 175)
    denim = Image.fromarray(denim_arr, mode="RGB")
    draw_d = ImageDraw.Draw(denim)
    for _ in range(50):
        bx, by = np.random.randint(0, w), np.random.randint(0, h)
        br = np.random.randint(8, 28)
        draw_d.ellipse([bx - br, by - br, bx + br, by + br], fill=(75, 18, 18))
        draw_d.ellipse([bx - br//2, by - br//2, bx + br//2, by + br//2], fill=(45, 10, 10))
    denim = denim.filter(ImageFilter.GaussianBlur(0.5))
    denim.save(f"{OUTPUT_DIR}/zombie_denim_pbr.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_denim_pbr.png", f"{OUTPUT_DIR}/zombie_denim_pbr_n.png", strength=2.4)

    # E. Red Flannel Fabric (Garwalfs Left Walker shirt)
    flannel = Image.new("RGB", (w, h), (145, 28, 24))
    draw_f = ImageDraw.Draw(flannel)
    for pos in range(0, w, 32):
        draw_f.line([(pos, 0), (pos, h)], fill=(75, 14, 12), width=6)
        draw_f.line([(0, pos), (w, pos)], fill=(75, 14, 12), width=6)
        draw_f.line([(pos + 12, 0), (pos + 12, h)], fill=(45, 10, 10), width=2)
        draw_f.line([(0, pos + 12), (w, pos + 12)], fill=(45, 10, 10), width=2)
    for _ in range(40):
        bx, by = np.random.randint(0, w), np.random.randint(0, h)
        br = np.random.randint(10, 30)
        draw_f.ellipse([bx - br, by - br, bx + br, by + br], fill=(55, 10, 10))
    flannel = flannel.filter(ImageFilter.GaussianBlur(0.6))
    flannel.save(f"{OUTPUT_DIR}/zombie_flannel_pbr.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_flannel_pbr.png", f"{OUTPUT_DIR}/zombie_flannel_pbr_n.png", strength=2.2)

    # F. Olive Tank Top Cotton (Garwalfs Right Walker tank top)
    tank = Image.new("RGB", (w, h), (85, 98, 65))
    draw_t = ImageDraw.Draw(tank)
    for x in range(0, w, 4):
        draw_t.line([(x, 0), (x, h)], fill=(65, 76, 50), width=1)
    for _ in range(45):
        bx, by = np.random.randint(0, w), np.random.randint(0, h)
        br = np.random.randint(6, 24)
        draw_t.ellipse([bx - br, by - br, bx + br, by + br], fill=(110, 18, 16))
    tank = tank.filter(ImageFilter.GaussianBlur(0.5))
    tank.save(f"{OUTPUT_DIR}/zombie_tanktop_pbr.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_tanktop_pbr.png", f"{OUTPUT_DIR}/zombie_tanktop_pbr_n.png", strength=2.2)

    # G. Distressed Leather & Fur Collar (Garwalfs Center Brute jacket)
    leather_arr = np.random.normal(90, 10, (h, w)).clip(60, 120).astype(np.uint8)
    lr = (leather_arr * 1.15).clip(0, 255).astype(np.uint8)
    lg = (leather_arr * 0.75).clip(0, 255).astype(np.uint8)
    lb = (leather_arr * 0.45).clip(0, 255).astype(np.uint8)
    leather = Image.fromarray(np.stack([lr, lg, lb], axis=-1), mode="RGB")
    draw_l = ImageDraw.Draw(leather)
    for _ in range(25):
        x1, y1 = np.random.randint(0, w), np.random.randint(0, h)
        x2, y2 = x1 + np.random.randint(-60, 60), y1 + np.random.randint(-60, 60)
        draw_l.line([(x1, y1), (x2, y2)], fill=(50, 28, 15), width=3)
        draw_l.line([(x1+1, y1+1), (x2+1, y2+1)], fill=(135, 95, 60), width=1)
    leather = leather.filter(ImageFilter.GaussianBlur(0.6))
    leather.save(f"{OUTPUT_DIR}/zombie_brute_leather_pbr.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_brute_leather_pbr.png", f"{OUTPUT_DIR}/zombie_brute_leather_pbr_n.png", strength=2.6)

    print("All PBR textures and normal maps generated successfully!")

# -------------------------------------------------------------
# 2. 8-DIRECTIONAL SPRITESHEET RENDERING FOR 2D GAMEPLAY
# -------------------------------------------------------------

def render_walker_directional_frame(angle_rad, variant_color="red", style="flannel", size=96):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    # Ground drop shadow
    draw.ellipse([cx - 16, cy + 24, cx + 16, cy + 38], fill=(12, 14, 16, 160))
    
    skin_base = (142, 152, 138)
    skin_shadow = (98, 108, 94)
    skin_blood = (120, 22, 22)
    denim_blue = (52, 78, 118)
    denim_dark = (32, 48, 76)
    fangs_col = (235, 235, 220)
    hair_col = (175, 172, 165)
    
    if variant_color == "red":
        shirt_main = (165, 34, 30)
        shirt_dark = (110, 20, 18)
        undershirt = (85, 95, 72)
        headgear = None
    elif variant_color == "green":
        shirt_main = (82, 98, 62)
        shirt_dark = (55, 68, 42)
        undershirt = (60, 70, 48)
        headgear = (175, 32, 28) # Red bandana
    elif variant_color == "blue":
        shirt_main = (45, 72, 112)
        shirt_dark = (28, 46, 75)
        undershirt = (65, 68, 72)
        headgear = None
    elif variant_color == "brown":
        shirt_main = (125, 82, 48)
        shirt_dark = (82, 52, 30)
        undershirt = (52, 48, 44)
        headgear = (65, 55, 48) # Dark cap
    else:
        shirt_main = (165, 34, 30)
        shirt_dark = (110, 20, 18)
        undershirt = (85, 95, 72)
        headgear = None

    # --- 1. LEGS & TATTERED DENIM SHORTS ---
    leg_y = cy + 14
    draw.rectangle([cx - 10, leg_y - 2, cx - 1, leg_y + 14], fill=denim_blue)
    draw.rectangle([cx + 1, leg_y - 2, cx + 10, leg_y + 14], fill=denim_blue)
    draw.line([(cx - 10, leg_y + 14), (cx - 1, leg_y + 14)], fill=denim_dark, width=2)
    draw.line([(cx + 1, leg_y + 14), (cx + 10, leg_y + 14)], fill=denim_dark, width=2)
    draw.rectangle([cx - 8, leg_y + 14, cx - 3, leg_y + 26], fill=skin_base)
    draw.rectangle([cx + 3, leg_y + 14, cx + 8, leg_y + 26], fill=skin_base)
    draw.line([(cx - 5, leg_y + 16), (cx - 5, leg_y + 22)], fill=skin_blood, width=1)
    draw.line([(cx + 5, leg_y + 18), (cx + 5, leg_y + 24)], fill=skin_blood, width=1)
    draw.ellipse([cx - 9, leg_y + 24, cx - 2, leg_y + 28], fill=skin_shadow)
    draw.ellipse([cx + 2, leg_y + 24, cx + 9, leg_y + 28], fill=skin_shadow)

    # --- 2. TORSO & CLOTHING LAYERS ---
    torso_w = 14
    torso_h = 16
    draw.ellipse([cx - torso_w, cy - 8, cx + torso_w, cy + 12], fill=shirt_dark)
    
    if style == "tank":
        draw.rectangle([cx - 8, cy - 6, cx + 8, cy + 10], fill=shirt_main)
        draw.circle((cx - 11, cy - 3), 5, fill=skin_base)
        draw.circle((cx + 11, cy - 3), 5, fill=skin_base)
    else:
        draw.ellipse([cx - 13, cy - 7, cx + 13, cy + 11], fill=shirt_main)
        if sin_a > -0.3:
            draw.rectangle([cx - 4, cy - 5, cx + 4, cy + 9], fill=undershirt)
            draw.line([(cx - 4, cy - 5), (cx - 4, cy + 9)], fill=shirt_dark, width=1)
            draw.line([(cx + 4, cy - 5), (cx + 4, cy + 9)], fill=shirt_dark, width=1)

    # --- 3. LUNGING ROTTING ARMS & CLAWS ---
    for side in [-10, 10]:
        sx = cx + side * (-sin_a) + cos_a * 4
        sy = cy + side * (cos_a) + sin_a * 4
        reach_x = sx + cos_a * 22
        reach_y = sy + sin_a * 22
        if style != "tank":
            draw.line([(sx, sy), (sx + cos_a * 8, sy + sin_a * 8)], fill=shirt_main, width=5)
            draw.line([(sx + cos_a * 8, sy + sin_a * 8), (reach_x, reach_y)], fill=skin_base, width=4)
        else:
            draw.line([(sx, sy), (reach_x, reach_y)], fill=skin_base, width=4)
        draw.circle((reach_x, reach_y), 3, fill=skin_blood)
        draw.line([(reach_x, reach_y), (reach_x + cos_a * 3, reach_y + sin_a * 3)], fill=fangs_col, width=1)

    # --- 4. SCULPTED ZOMBIE HEAD & FANGS ---
    head_cx = cx + cos_a * 3
    head_cy = cy - 12 + sin_a * 2
    
    draw.ellipse([head_cx - 8, head_cy - 8, head_cx + 8, head_cy + 8], fill=skin_base)
    
    if headgear:
        draw.ellipse([head_cx - 8, head_cy - 9, head_cx + 8, head_cy - 1], fill=headgear)
    else:
        draw.polygon([(head_cx - 7, head_cy - 7), (head_cx - 9, head_cy - 13), (head_cx - 4, head_cy - 9)], fill=hair_col)
        draw.polygon([(head_cx - 3, head_cy - 8), (head_cx, head_cy - 14), (head_cx + 3, head_cy - 8)], fill=hair_col)
        draw.polygon([(head_cx + 4, head_cy - 9), (head_cx + 9, head_cy - 13), (head_cx + 7, head_cy - 7)], fill=hair_col)
        
    if sin_a > -0.4:
        face_x = head_cx + cos_a * 4
        face_y = head_cy + sin_a * 3
        draw.circle((face_x - 3, face_y - 2), 2, fill=(25, 20, 20))
        draw.circle((face_x + 3, face_y - 2), 2, fill=(25, 20, 20))
        draw.circle((face_x - 3, face_y - 2), 1, fill=(225, 45, 30))
        draw.circle((face_x + 3, face_y - 2), 1, fill=(225, 45, 30))
        draw.ellipse([face_x - 5, face_y + 2, face_x + 5, face_y + 7], fill=(20, 8, 8))
        draw.line([(face_x - 3, face_y + 2), (face_x - 3, face_y + 5)], fill=fangs_col, width=1)
        draw.line([(face_x + 3, face_y + 2), (face_x + 3, face_y + 5)], fill=fangs_col, width=1)
        draw.line([(face_x, face_y + 4), (face_x, face_y + 7)], fill=fangs_col, width=1)

    return img

def render_heavy_brute_directional_frame(angle_rad, size=128):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    
    draw.ellipse([cx - 28, cy + 34, cx + 28, cy + 52], fill=(10, 12, 14, 180))
    
    skin_base = (138, 145, 132)
    skin_shadow = (92, 98, 88)
    vein_col = (115, 22, 22)
    leather_brown = (135, 78, 42)
    leather_dark = (85, 46, 22)
    fur_collar = (228, 222, 205)
    fur_shadow = (175, 168, 150)
    denim_blue = (48, 72, 108)
    denim_dark = (28, 44, 68)
    fangs_col = (245, 245, 230)
    hair_col = (195, 192, 185)

    # Legs
    leg_y = cy + 20
    draw.rectangle([cx - 14, leg_y - 2, cx - 2, leg_y + 18], fill=denim_blue)
    draw.rectangle([cx + 2, leg_y - 2, cx + 14, leg_y + 18], fill=denim_blue)
    draw.line([(cx - 14, leg_y + 18), (cx - 2, leg_y + 18)], fill=denim_dark, width=2)
    draw.line([(cx + 2, leg_y + 18), (cx + 14, leg_y + 18)], fill=denim_dark, width=2)
    draw.rectangle([cx - 12, leg_y + 18, cx - 4, leg_y + 34], fill=skin_base)
    draw.rectangle([cx + 4, leg_y + 18, cx + 12, leg_y + 34], fill=skin_base)
    draw.ellipse([cx - 14, leg_y + 32, cx - 3, leg_y + 38], fill=skin_shadow)
    draw.ellipse([cx + 3, leg_y + 32, cx + 14, leg_y + 38], fill=skin_shadow)

    # Hunched Torso & Leather Fur Jacket
    draw.ellipse([cx - 22, cy - 14, cx + 22, cy + 18], fill=leather_dark)
    draw.ellipse([cx - 19, cy - 12, cx + 19, cy + 16], fill=leather_brown)
    draw.ellipse([cx - 21, cy - 18, cx + 21, cy - 2], fill=fur_shadow)
    draw.ellipse([cx - 18, cy - 17, cx + 18, cy - 4], fill=fur_collar)
    
    # Colossal Hypertrophied Arms
    for side in [-18, 18]:
        sx = cx + side * (-sin_a) + cos_a * 8
        sy = cy + side * (cos_a) + sin_a * 8
        draw.circle((sx, sy), 10, fill=skin_base)
        
        reach_x = sx + cos_a * 28
        reach_y = sy + sin_a * 28
        draw.line([(sx, sy), (reach_x, reach_y)], fill=skin_base, width=9)
        draw.line([(sx + 1, sy + 1), (reach_x - cos_a * 4, reach_y - sin_a * 4)], fill=vein_col, width=2)
        draw.circle((reach_x, reach_y), 6, fill=skin_shadow)
        for fo in [-3, 0, 3]:
            draw.line([(reach_x, reach_y), (reach_x + cos_a * 5 + fo * (-sin_a), reach_y + sin_a * 5 + fo * cos_a)], fill=fangs_col, width=2)

    # Hunched Head
    head_cx = cx + cos_a * 6
    head_cy = cy - 16 + sin_a * 3
    draw.circle((head_cx, head_cy), 11, fill=skin_base)
    
    draw.polygon([(head_cx - 9, head_cy - 8), (head_cx - 12, head_cy - 16), (head_cx - 5, head_cy - 10)], fill=hair_col)
    draw.polygon([(head_cx - 4, head_cy - 9), (head_cx, head_cy - 18), (head_cx + 4, head_cy - 9)], fill=hair_col)
    draw.polygon([(head_cx + 5, head_cy - 10), (head_cx + 12, head_cy - 16), (head_cx + 9, head_cy - 8)], fill=hair_col)

    if sin_a > -0.4:
        face_x = head_cx + cos_a * 5
        face_y = head_cy + sin_a * 4
        draw.circle((face_x - 4, face_y - 2), 2, fill=(240, 35, 20))
        draw.circle((face_x + 4, face_y - 2), 2, fill=(240, 35, 20))
        draw.ellipse([face_x - 7, face_y + 3, face_x + 7, face_y + 10], fill=(15, 6, 6))
        for toff in [-5, -2, 2, 5]:
            draw.line([(face_x + toff, face_y + 3), (face_x + toff, face_y + 7)], fill=fangs_col, width=2)

    return img

def build_all_spritesheets():
    angles = [0, math.pi / 4, math.pi / 2, 3 * math.pi / 4, math.pi, -3 * math.pi / 4, -math.pi / 2, -math.pi / 4]
    
    # 1. Variant Red Flannel Walker (Garwalfs Model 1)
    sheet_red = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        sheet_red.paste(render_walker_directional_frame(a, variant_color="red", style="flannel"), (i * 96, 0))
    sheet_red.save(f"{OUTPUT_DIR}/zombie_regular_8dir.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_regular_8dir.png", f"{OUTPUT_DIR}/zombie_regular_8dir_n.png", strength=2.8)

    # 2. Variant Green Tank Top + Bandana Walker (Garwalfs Model 3)
    sheet_green = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        sheet_green.paste(render_walker_directional_frame(a, variant_color="green", style="tank"), (i * 96, 0))
    sheet_green.save(f"{OUTPUT_DIR}/zombie_regular_green_8dir.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_regular_green_8dir.png", f"{OUTPUT_DIR}/zombie_regular_green_8dir_n.png", strength=2.8)

    # 3. Variant Blue Denim Walker
    sheet_blue = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        sheet_blue.paste(render_walker_directional_frame(a, variant_color="blue", style="flannel"), (i * 96, 0))
    sheet_blue.save(f"{OUTPUT_DIR}/zombie_regular_blue_8dir.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_regular_blue_8dir.png", f"{OUTPUT_DIR}/zombie_regular_blue_8dir_n.png", strength=2.8)

    # 4. Variant Brown Leather/Workwear Walker
    sheet_brown = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        sheet_brown.paste(render_walker_directional_frame(a, variant_color="brown", style="flannel"), (i * 96, 0))
    sheet_brown.save(f"{OUTPUT_DIR}/zombie_regular_brown_8dir.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_regular_brown_8dir.png", f"{OUTPUT_DIR}/zombie_regular_brown_8dir_n.png", strength=2.8)

    # 5. Heavy Brute in Fur Collar Jacket (Garwalfs Model 2)
    sheet_heavy = Image.new("RGBA", (128 * 8, 128), (0, 0, 0, 0))
    for i, a in enumerate(angles):
        sheet_heavy.paste(render_heavy_brute_directional_frame(a), (i * 128, 0))
    sheet_heavy.save(f"{OUTPUT_DIR}/zombie_heavy_8dir.png")
    generate_normal_map(f"{OUTPUT_DIR}/zombie_heavy_8dir.png", f"{OUTPUT_DIR}/zombie_heavy_8dir_n.png", strength=3.2)

    print("All 8-directional zombie variant spritesheets and normal maps built successfully!")

if __name__ == "__main__":
    build_pbr_textures()
    build_all_spritesheets()
