import os
import numpy as np
from PIL import Image

def generate_normal_map(input_path, output_path, strength=2.5, invert_y=False):
    img = Image.open(input_path)
    has_alpha = (img.mode == 'RGBA')
    
    if has_alpha:
        r, g, b, a = img.split()
        alpha = np.array(a, dtype=np.float32) / 255.0
        gray = img.convert('L')
    else:
        gray = img.convert('L')
        alpha = None
        
    arr = np.array(gray, dtype=np.float32) / 255.0
    h, w = arr.shape
    
    # Wrap for tiling ground, edge clamp for props/characters
    mode = 'wrap' if 'ground' in input_path else 'edge'
    padded = np.pad(arr, 1, mode=mode)
    
    # Sobel kernels
    dx = (
        (padded[:-2, 2:] + 2 * padded[1:-1, 2:] + padded[2:, 2:]) -
        (padded[:-2, :-2] + 2 * padded[1:-1, :-2] + padded[2:, :-2])
    ) * strength
    
    dy = (
        (padded[2:, :-2] + 2 * padded[2:, 1:-1] + padded[2:, 2:]) -
        (padded[:-2, :-2] + 2 * padded[:-2, 1:-1] + padded[:-2, 2:])
    ) * strength
    
    if invert_y:
        dy = -dy
        
    dz = np.ones_like(dx)
    
    # Normalize vector
    norm = np.sqrt(dx * dx + dy * dy + dz * dz)
    norm = np.maximum(norm, 1e-6)
    
    nx = dx / norm
    ny = dy / norm
    nz = dz / norm
    
    # Map [-1, 1] to [0, 255] (Godot 2D normal map encoding)
    r_channel = ((nx * 0.5 + 0.5) * 255).astype(np.uint8)
    g_channel = (((-ny if not invert_y else ny) * 0.5 + 0.5) * 255).astype(np.uint8)
    b_channel = ((nz * 0.5 + 0.5) * 255).astype(np.uint8)
    
    if has_alpha:
        a_channel = (alpha * 255).astype(np.uint8)
        norm_img = Image.fromarray(np.stack([r_channel, g_channel, b_channel, a_channel], axis=-1), mode='RGBA')
    else:
        norm_img = Image.fromarray(np.stack([r_channel, g_channel, b_channel], axis=-1), mode='RGB')
        
    norm_img.save(output_path)
    print(f"Generated normal map: {output_path}")

def main():
    targets = [
        ("assets/textures/ground/dirt_terrain.png", "assets/textures/ground/dirt_terrain_n.png", 3.0),
        ("assets/textures/ground/cracked_asphalt.png", "assets/textures/ground/cracked_asphalt_n.png", 3.5),
        ("assets/textures/ground/dead_grass.png", "assets/textures/ground/dead_grass_n.png", 2.2),
        ("assets/textures/railway/railway_track.png", "assets/textures/railway/railway_track_n.png", 4.0),
        ("assets/textures/railway/hazard_platform.png", "assets/textures/railway/hazard_platform_n.png", 3.2),
        ("assets/textures/environment/concrete_wall_h.png", "assets/textures/environment/concrete_wall_h_n.png", 3.5),
        ("assets/textures/environment/concrete_wall_v.png", "assets/textures/environment/concrete_wall_v_n.png", 3.5),
        ("assets/textures/environment/bunker_building.png", "assets/textures/environment/bunker_building_n.png", 3.0),
        ("assets/textures/environment/military_truck_wreck.png", "assets/textures/environment/military_truck_wreck_n.png", 3.2),
        ("assets/textures/props/crate_isometric.png", "assets/textures/props/crate_isometric_n.png", 3.2),
        ("assets/textures/props/oil_barrel.png", "assets/textures/props/oil_barrel_n.png", 3.8),
        ("assets/textures/characters/soldier_8dir.png", "assets/textures/characters/soldier_8dir_n.png", 2.2),
        ("assets/textures/characters/zombie_regular_8dir.png", "assets/textures/characters/zombie_regular_8dir_n.png", 2.2),
        ("assets/textures/characters/zombie_dog_8dir.png", "assets/textures/characters/zombie_dog_8dir_n.png", 2.0),
        ("assets/textures/characters/zombie_heavy_8dir.png", "assets/textures/characters/zombie_heavy_8dir_n.png", 2.5),
        ("assets/textures/characters/zombie_spitter_8dir.png", "assets/textures/characters/zombie_spitter_8dir_n.png", 2.2),
        ("assets/textures/characters/zombie_armored_8dir.png", "assets/textures/characters/zombie_armored_8dir_n.png", 3.0),
        ("assets/textures/characters/zombie_colossus_8dir.png", "assets/textures/characters/zombie_colossus_8dir_n.png", 3.2),
    ]
    
    for in_path, out_path, strength in targets:
        if os.path.exists(in_path):
            generate_normal_map(in_path, out_path, strength=strength)
        else:
            print(f"Skipping missing file: {in_path}")

if __name__ == "__main__":
    main()
