import os
import math
import numpy as np
from PIL import Image, ImageOps, ImageFilter, ImageEnhance
import sys

sys.path.insert(0, os.getcwd())
from tools.generate_normal_maps import generate_normal_map

OUTPUT_DIR = "assets/textures/characters"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def build_walker_sheet(base_char_img, output_name, color_shift=None):
    # base_char_img is RGBA
    char = base_char_img.copy()
    
    if color_shift:
        # Apply color shift to shirt / clothes
        arr = np.array(char).astype(np.float32)
        r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
        if color_shift == "blue":
            # Shift red shirt to blue
            is_red = (r > g + 25) & (r > b + 25) & (a > 100)
            arr[is_red, 0] = g[is_red] * 0.7
            arr[is_red, 1] = g[is_red] * 1.1
            arr[is_red, 2] = r[is_red] * 1.05
        elif color_shift == "brown":
            # Shift red shirt to brown
            is_red = (r > g + 25) & (r > b + 25) & (a > 100)
            arr[is_red, 0] = r[is_red] * 0.85
            arr[is_red, 1] = r[is_red] * 0.55
            arr[is_red, 2] = r[is_red] * 0.35
        char = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA")
        
    bbox = char.getbbox()
    if bbox:
        char = char.crop(bbox)
        
    # Scale to 78px height (so it fits nicely in 96x96 with ground contact at y=84)
    target_h = 76
    w, h = char.size
    target_w = max(1, int(w * (target_h / h)))
    front_center = char.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # Generate 8 directions:
    # 0: East (facing right)
    east_w = int(target_w * 0.70)
    east = front_center.resize((east_w, target_h), Image.Resampling.LANCZOS)
    
    # 1: South-East (front-right quarter)
    se_w = int(target_w * 0.90)
    se = front_center.resize((se_w, target_h), Image.Resampling.LANCZOS)
    
    # 2: South (front facing)
    south = front_center
    
    # 3: South-West (front-left quarter)
    sw = ImageOps.mirror(se)
    
    # 4: West (facing left)
    west = ImageOps.mirror(east)
    
    # 5: North-West (rear-left quarter): darken and shadow back
    rear_base = front_center.copy()
    r_arr = np.array(rear_base)
    # Darken slightly to represent back view facing away from camera light
    r_arr[:, :, :3] = (r_arr[:, :, :3] * 0.82).astype(np.uint8)
    rear_img = Image.fromarray(r_arr, mode="RGBA")
    nw = ImageOps.mirror(rear_img.resize((se_w, target_h), Image.Resampling.LANCZOS))
    
    # 6: North (direct rear view)
    north = rear_img
    
    # 7: North-East (rear-right quarter)
    ne = rear_img.resize((se_w, target_h), Image.Resampling.LANCZOS)
    
    def place_in_frame(img, frame_size=(96, 96)):
        canvas = Image.new("RGBA", frame_size, (0, 0, 0, 0))
        # Ground contact shadow under feet
        shadow = Image.new("RGBA", frame_size, (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(shadow)
        cx = frame_size[0] // 2
        cy = frame_size[1] - 12
        s_draw.ellipse([cx - 14, cy - 5, cx + 14, cy + 5], fill=(10, 12, 14, 140))
        shadow = shadow.filter(ImageFilter.GaussianBlur(1.2))
        canvas.paste(shadow, (0, 0), shadow)
        
        # Paste character
        px = (frame_size[0] - img.size[0]) // 2
        py = frame_size[1] - img.size[1] - 12
        canvas.paste(img, (px, py), img)
        return canvas

    sheet = Image.new("RGBA", (96 * 8, 96), (0, 0, 0, 0))
    frames = [
        place_in_frame(east),
        place_in_frame(se),
        place_in_frame(south),
        place_in_frame(sw),
        place_in_frame(west),
        place_in_frame(nw),
        place_in_frame(north),
        place_in_frame(ne)
    ]
    for i, f in enumerate(frames):
        sheet.paste(f, (i * 96, 0), f)
        
    out_path = f"{OUTPUT_DIR}/{output_name}.png"
    norm_path = f"{OUTPUT_DIR}/{output_name}_n.png"
    sheet.save(out_path)
    generate_normal_map(out_path, norm_path, strength=2.8)
    print(f"Generated {out_path} and {norm_path}")

def build_brute_sheet(char_img):
    bbox = char_img.getbbox()
    cropped = char_img.crop(bbox)
    target_h = 104
    w, h = cropped.size
    target_w = max(1, int(w * (target_h / h)))
    front_center = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    east_w = int(target_w * 0.72)
    east = front_center.resize((east_w, target_h), Image.Resampling.LANCZOS)
    se_w = int(target_w * 0.90)
    se = front_center.resize((se_w, target_h), Image.Resampling.LANCZOS)
    south = front_center
    sw = ImageOps.mirror(se)
    west = ImageOps.mirror(east)
    
    r_arr = np.array(front_center)
    r_arr[:, :, :3] = (r_arr[:, :, :3] * 0.82).astype(np.uint8)
    rear_img = Image.fromarray(r_arr, mode="RGBA")
    nw = ImageOps.mirror(rear_img.resize((se_w, target_h), Image.Resampling.LANCZOS))
    north = rear_img
    ne = rear_img.resize((se_w, target_h), Image.Resampling.LANCZOS)
    
    def place_in_frame_heavy(img, frame_size=(128, 128)):
        canvas = Image.new("RGBA", frame_size, (0, 0, 0, 0))
        shadow = Image.new("RGBA", frame_size, (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(shadow)
        cx = frame_size[0] // 2
        cy = frame_size[1] - 14
        s_draw.ellipse([cx - 22, cy - 8, cx + 22, cy + 8], fill=(8, 10, 12, 160))
        shadow = shadow.filter(ImageFilter.GaussianBlur(1.8))
        canvas.paste(shadow, (0, 0), shadow)
        
        px = (frame_size[0] - img.size[0]) // 2
        py = frame_size[1] - img.size[1] - 14
        canvas.paste(img, (px, py), img)
        return canvas

    sheet = Image.new("RGBA", (128 * 8, 128), (0, 0, 0, 0))
    frames = [
        place_in_frame_heavy(east),
        place_in_frame_heavy(se),
        place_in_frame_heavy(south),
        place_in_frame_heavy(sw),
        place_in_frame_heavy(west),
        place_in_frame_heavy(nw),
        place_in_frame_heavy(north),
        place_in_frame_heavy(ne)
    ]
    for i, f in enumerate(frames):
        sheet.paste(f, (i * 128, 0), f)
        
    out_path = f"{OUTPUT_DIR}/zombie_heavy_8dir.png"
    norm_path = f"{OUTPUT_DIR}/zombie_heavy_8dir_n.png"
    sheet.save(out_path)
    generate_normal_map(out_path, norm_path, strength=3.2)
    print(f"Generated {out_path} and {norm_path}")

if __name__ == "__main__":
    from PIL import ImageDraw
    
    # 1. Red Flannel Walker (Model 1)
    red_img = Image.open("tools/extracted/iso_red_pure.png")
    build_walker_sheet(red_img, "zombie_regular_8dir")
    
    # 2. Green Tank Top Walker (Model 2)
    tank_img = Image.open("tools/extracted/char_tank_walker.png")
    build_walker_sheet(tank_img, "zombie_regular_green_8dir")
    
    # 3. Blue Denim Walker (Model 3)
    build_walker_sheet(red_img, "zombie_regular_blue_8dir", color_shift="blue")
    
    # 4. Brown Workwear Walker (Model 4)
    build_walker_sheet(red_img, "zombie_regular_brown_8dir", color_shift="brown")
    
    # 5. Heavy Brute with Fur Collar (Center Model)
    brute_img = Image.open("tools/extracted/final_brute.png")
    build_brute_sheet(brute_img)
    
    print("All final 3D model spritesheets created successfully!")
