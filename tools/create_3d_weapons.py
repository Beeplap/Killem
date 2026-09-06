import os
import math

def write_obj_file(filename, vertices, normals, uvs, faces_by_material, material_lib="weapons.mtl"):
    with open(filename, "w") as f:
        f.write(f"# Wavefront OBJ generated for Godot 3D Zombie Shooter\n")
        f.write(f"mtllib {material_lib}\n\n")
        
        for v in vertices:
            f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
        f.write("\n")
        
        for vn in normals:
            f.write(f"vn {vn[0]:.4f} {vn[1]:.4f} {vn[2]:.4f}\n")
        f.write("\n")
        
        for vt in uvs:
            f.write(f"vt {vt[0]:.4f} {vt[1]:.4f}\n")
        f.write("\n")
        
        for mat_name, faces in faces_by_material.items():
            f.write(f"usemtl {mat_name}\n")
            for face in faces:
                # face is list of (v_idx, vt_idx, vn_idx) 1-based
                f_str = " ".join([f"{idx[0]}/{idx[1]}/{idx[2]}" for idx in face])
                f.write(f"f {f_str}\n")
            f.write("\n")

class MeshBuilder:
    def __init__(self):
        self.vertices = []
        self.normals = []
        self.uvs = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
        self.faces = {} # mat_name -> list of faces

    def add_box(self, cx, cy, cz, sx, sy, sz, mat="Gunmetal"):
        # sx, sy, sz are total widths
        hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
        v_start = len(self.vertices) + 1
        
        # 8 corners
        corners = [
            (cx - hx, cy - hy, cz - hz), # 0
            (cx + hx, cy - hy, cz - hz), # 1
            (cx + hx, cy + hy, cz - hz), # 2
            (cx - hx, cy + hy, cz - hz), # 3
            (cx - hx, cy - hy, cz + hz), # 4
            (cx + hx, cy - hy, cz + hz), # 5
            (cx + hx, cy + hy, cz + hz), # 6
            (cx - hx, cy + hy, cz + hz), # 7
        ]
        self.vertices.extend(corners)
        
        # 6 face normals
        n_start = len(self.normals) + 1
        self.normals.extend([
            (0, 0, -1), # North (-Z)
            (0, 0, 1),  # South (+Z)
            (-1, 0, 0), # West (-X)
            (1, 0, 0),  # East (+X)
            (0, 1, 0),  # Up (+Y)
            (0, -1, 0)  # Down (-Y)
        ])
        
        if mat not in self.faces:
            self.faces[mat] = []
            
        # Faces: (v, vt, vn)
        # -Z face (0, 3, 2, 1)
        self.faces[mat].append([
            (v_start + 0, 1, n_start + 0),
            (v_start + 3, 4, n_start + 0),
            (v_start + 2, 3, n_start + 0),
            (v_start + 1, 2, n_start + 0)
        ])
        # +Z face (4, 5, 6, 7)
        self.faces[mat].append([
            (v_start + 4, 1, n_start + 1),
            (v_start + 5, 2, n_start + 1),
            (v_start + 6, 3, n_start + 1),
            (v_start + 7, 4, n_start + 1)
        ])
        # -X face (0, 4, 7, 3)
        self.faces[mat].append([
            (v_start + 0, 1, n_start + 2),
            (v_start + 4, 2, n_start + 2),
            (v_start + 7, 3, n_start + 2),
            (v_start + 3, 4, n_start + 2)
        ])
        # +X face (1, 2, 6, 5)
        self.faces[mat].append([
            (v_start + 1, 1, n_start + 3),
            (v_start + 2, 4, n_start + 3),
            (v_start + 6, 3, n_start + 3),
            (v_start + 5, 2, n_start + 3)
        ])
        # +Y face (3, 7, 6, 2)
        self.faces[mat].append([
            (v_start + 3, 1, n_start + 4),
            (v_start + 7, 2, n_start + 4),
            (v_start + 6, 3, n_start + 4),
            (v_start + 2, 4, n_start + 4)
        ])
        # -Y face (0, 1, 5, 4)
        self.faces[mat].append([
            (v_start + 0, 1, n_start + 5),
            (v_start + 1, 2, n_start + 5),
            (v_start + 5, 3, n_start + 5),
            (v_start + 4, 4, n_start + 5)
        ])

    def add_cylinder(self, cx, cy, cz_start, cz_end, radius, segments=8, mat="Gunmetal"):
        # Cylinder aligned along Z axis
        v_start = len(self.vertices) + 1
        n_start = len(self.normals) + 1
        
        # Add side normals and vertices
        for i in range(segments):
            angle = (2.0 * math.pi * i) / segments
            nx = math.cos(angle)
            ny = math.sin(angle)
            self.normals.append((nx, ny, 0.0))
            
            x = cx + radius * nx
            y = cy + radius * ny
            self.vertices.append((x, y, cz_start))
            self.vertices.append((x, y, cz_end))
            
        if mat not in self.faces:
            self.faces[mat] = []
            
        for i in range(segments):
            i_next = (i + 1) % segments
            v0 = v_start + (i * 2)
            v1 = v_start + (i * 2) + 1
            v2 = v_start + (i_next * 2) + 1
            v3 = v_start + (i_next * 2)
            
            n0 = n_start + i
            n1 = n_start + i_next
            
            self.faces[mat].append([
                (v0, 1, n0),
                (v1, 2, n0),
                (v2, 3, n1),
                (v3, 4, n1)
            ])
            
        # End caps
        n_cap_start = len(self.normals) + 1
        self.normals.append((0, 0, -1)) # start cap
        self.normals.append((0, 0, 1))  # end cap
        
        cap1_v = [(v_start + i * 2, 1, n_cap_start) for i in reversed(range(segments))]
        cap2_v = [(v_start + i * 2 + 1, 1, n_cap_start + 1) for i in range(segments)]
        self.faces[mat].append(cap1_v)
        self.faces[mat].append(cap2_v)

def build_pistol():
    b = MeshBuilder()
    # 1. Receiver & Grip
    b.add_box(0.0, -0.06, -0.02, 0.032, 0.12, 0.045, "PolymerBlack")
    # Trigger guard
    b.add_box(0.0, -0.03, 0.025, 0.015, 0.04, 0.035, "PolymerBlack")
    # Trigger
    b.add_box(0.0, -0.025, 0.022, 0.008, 0.02, 0.01, "Steel")
    # 2. Slide
    b.add_box(0.0, 0.02, 0.01, 0.036, 0.038, 0.18, "Gunmetal")
    # Slide serrations top
    b.add_box(0.0, 0.038, 0.01, 0.034, 0.006, 0.16, "SteelDark")
    # Sights
    b.add_box(0.0, 0.045, -0.07, 0.01, 0.012, 0.012, "Steel")
    b.add_box(0.0, 0.045, 0.09, 0.008, 0.012, 0.01, "Steel")
    # 3. Suppressor / Silencer
    b.add_cylinder(0.0, 0.02, 0.10, 0.25, 0.019, segments=12, mat="GunmetalMatte")
    b.add_cylinder(0.0, 0.02, 0.25, 0.26, 0.021, segments=12, mat="SteelDark")
    # 4. Underbarrel rail/laser
    b.add_box(0.0, -0.01, 0.06, 0.028, 0.022, 0.065, "PolymerBlack")
    b.add_cylinder(0.0, -0.01, 0.09, 0.095, 0.006, segments=8, mat="LaserRed")
    return b

def build_shotgun():
    b = MeshBuilder()
    # 1. Tactical rear stock
    b.add_box(0.0, -0.02, -0.22, 0.034, 0.09, 0.18, "PolymerBlack")
    b.add_box(0.0, -0.02, -0.31, 0.038, 0.11, 0.02, "RubberBlack")
    # 2. Grip
    b.add_box(0.0, -0.08, -0.10, 0.032, 0.10, 0.045, "PolymerBlack")
    # Trigger guard & trigger
    b.add_box(0.0, -0.04, -0.06, 0.016, 0.035, 0.03, "Steel")
    # 3. Receiver
    b.add_box(0.0, 0.01, -0.02, 0.042, 0.065, 0.15, "Gunmetal")
    # 4. Side Shell Rack (4 red shells)
    b.add_box(0.026, 0.01, -0.02, 0.012, 0.045, 0.12, "PolymerBlack")
    for s_idx in range(4):
        z_pos = -0.06 + (s_idx * 0.032)
        b.add_cylinder(0.032, 0.01, z_pos - 0.01, z_pos + 0.012, 0.009, segments=8, mat="ShotgunRed")
        b.add_cylinder(0.032, 0.01, z_pos - 0.014, z_pos - 0.01, 0.0092, segments=8, mat="Brass")
    # 5. Barrel & Magazine tube
    b.add_cylinder(0.0, 0.028, 0.055, 0.48, 0.014, segments=12, mat="SteelDark")
    b.add_cylinder(0.0, -0.005, 0.055, 0.44, 0.012, segments=10, mat="Gunmetal")
    # 6. Perforated heat shield
    b.add_box(0.0, 0.036, 0.24, 0.034, 0.018, 0.28, "Steel")
    # 7. Ribbed pump forend
    b.add_cylinder(0.0, -0.005, 0.16, 0.29, 0.022, segments=10, mat="PolymerBlack")
    return b

def build_rifle():
    b = MeshBuilder()
    # 1. Adjustable Crane Stock
    b.add_box(0.0, -0.01, -0.22, 0.032, 0.07, 0.16, "PolymerBlack")
    b.add_cylinder(0.0, 0.01, -0.25, -0.08, 0.015, segments=8, mat="Steel")
    # 2. Pistol grip
    b.add_box(0.0, -0.08, -0.07, 0.03, 0.11, 0.042, "PolymerBlack")
    # 3. Receiver
    b.add_box(0.0, 0.01, -0.02, 0.038, 0.075, 0.16, "Gunmetal")
    # Extended 30rd curved Magazine
    b.add_box(0.0, -0.11, 0.04, 0.028, 0.14, 0.065, "PolymerBlack")
    b.add_box(0.0, -0.16, 0.06, 0.026, 0.06, 0.06, "PolymerBlack")
    # 4. Top Picatinny Rail
    b.add_box(0.0, 0.052, 0.04, 0.024, 0.012, 0.24, "SteelDark")
    # 5. Holographic Sight
    b.add_box(0.0, 0.065, 0.01, 0.032, 0.015, 0.06, "PolymerBlack") # Base
    b.add_box(0.0, 0.09, 0.01, 0.034, 0.035, 0.065, "Gunmetal")     # Hood
    b.add_box(0.0, 0.09, 0.01, 0.024, 0.025, 0.05, "SightGlass")    # Lens aperture
    # 6. Handguard
    b.add_box(0.0, 0.015, 0.18, 0.042, 0.055, 0.18, "GunmetalMatte")
    # 7. Barrel & Flash hider
    b.add_cylinder(0.0, 0.02, 0.27, 0.44, 0.011, segments=10, mat="SteelDark")
    b.add_cylinder(0.0, 0.02, 0.44, 0.48, 0.015, segments=10, mat="Gunmetal")
    return b

def build_flamethrower():
    b = MeshBuilder()
    # 1. Dual Fuel Canisters
    b.add_cylinder(-0.055, 0.0, -0.12, 0.14, 0.042, segments=12, mat="HazardYellow")
    b.add_cylinder(0.055, 0.0, -0.12, 0.14, 0.042, segments=12, mat="HazardYellow")
    # Tank caps & valves
    b.add_box(0.0, 0.0, 0.01, 0.14, 0.03, 0.16, "SteelDark")
    b.add_cylinder(-0.055, 0.0, 0.14, 0.165, 0.02, segments=8, mat="Brass")
    b.add_cylinder(0.055, 0.0, 0.14, 0.165, 0.02, segments=8, mat="Brass")
    # 2. Handles & Frame
    b.add_box(0.0, -0.08, 0.08, 0.035, 0.12, 0.05, "PolymerBlack")
    b.add_box(0.0, 0.09, 0.22, 0.04, 0.06, 0.04, "PolymerBlack")
    # 3. Main Flame Burner Barrel
    b.add_cylinder(0.0, 0.02, 0.14, 0.50, 0.026, segments=12, mat="SteelDark")
    # Flame shield shroud
    b.add_cylinder(0.0, 0.02, 0.46, 0.54, 0.045, segments=12, mat="Gunmetal")
    # Flared Nozzle
    b.add_cylinder(0.0, 0.02, 0.54, 0.60, 0.038, segments=12, mat="Steel")
    # Pilot light nozzle & spark igniter
    b.add_cylinder(0.0, 0.062, 0.50, 0.58, 0.008, segments=8, mat="Brass")
    b.add_box(0.0, 0.062, 0.59, 0.012, 0.012, 0.012, "FlamePilot")
    return b

def build_minigun():
    b = MeshBuilder()
    # 1. Drive motor housing
    b.add_cylinder(0.0, 0.0, -0.22, 0.04, 0.075, segments=14, mat="Gunmetal")
    b.add_box(0.0, 0.07, -0.09, 0.06, 0.06, 0.18, "PolymerBlack") # Top motor casing
    # Rear spade handles
    b.add_box(0.0, 0.0, -0.26, 0.18, 0.03, 0.04, "SteelDark")
    b.add_cylinder(-0.08, 0.0, -0.28, -0.24, 0.018, segments=8, mat="PolymerBlack")
    b.add_cylinder(0.08, 0.0, -0.28, -0.24, 0.018, segments=8, mat="PolymerBlack")
    # Side ammo feed bracket
    b.add_box(-0.09, -0.02, -0.08, 0.05, 0.06, 0.08, "Steel")
    # 2. Rotor disc
    b.add_cylinder(0.0, 0.0, 0.04, 0.07, 0.068, segments=14, mat="SteelDark")
    # 3. 6 Barrels in circle
    barrel_radius = 0.042
    for b_idx in range(6):
        b_ang = (2.0 * math.pi * b_idx) / 6.0
        bx = barrel_radius * math.cos(b_ang)
        by = barrel_radius * math.sin(b_ang)
        b.add_cylinder(bx, by, 0.07, 0.56, 0.0095, segments=8, mat="Steel")
        # Muzzle flash hider
        b.add_cylinder(bx, by, 0.56, 0.59, 0.012, segments=8, mat="Gunmetal")
    # 4. Clamp rings
    b.add_cylinder(0.0, 0.0, 0.28, 0.31, 0.065, segments=12, mat="SteelDark")
    b.add_cylinder(0.0, 0.0, 0.52, 0.55, 0.065, segments=12, mat="SteelDark")
    return b

def build_swat_operator():
    b = MeshBuilder()
    # 1. Tactical Legs & Combat Boots
    b.add_box(-0.11, 0.42, 0.0, 0.12, 0.82, 0.14, "CamoNavy")    # Left Leg
    b.add_box(0.11, 0.42, 0.0, 0.12, 0.82, 0.14, "CamoNavy")     # Right Leg
    b.add_box(-0.11, 0.38, 0.08, 0.10, 0.10, 0.04, "KneePads")    # Left Knee Pad
    b.add_box(0.11, 0.38, 0.08, 0.10, 0.10, 0.04, "KneePads")     # Right Knee Pad
    b.add_box(-0.11, 0.08, 0.04, 0.13, 0.16, 0.22, "BootsBlack")  # Left Boot
    b.add_box(0.11, 0.08, 0.04, 0.13, 0.16, 0.22, "BootsBlack")   # Right Boot
    # 2. Torso with Heavy Tactical Plate Carrier / Chest Rig
    b.add_box(0.0, 1.10, 0.0, 0.36, 0.55, 0.24, "CamoNavy")       # Torso Base
    b.add_box(0.0, 1.12, 0.02, 0.38, 0.48, 0.26, "VestBlack")     # Plate Carrier
    # Ammo pouches on chest
    b.add_box(-0.10, 1.05, 0.16, 0.07, 0.16, 0.05, "PouchCamo")
    b.add_box(0.0, 1.05, 0.16, 0.07, 0.16, 0.05, "PouchCamo")
    b.add_box(0.10, 1.05, 0.16, 0.07, 0.16, 0.05, "PouchCamo")
    # 3. Head & Tactical Helmet with NVG Mount
    b.add_box(0.0, 1.54, 0.0, 0.18, 0.20, 0.19, "Balaclava")      # Head / Face
    b.add_box(0.0, 1.62, -0.01, 0.23, 0.16, 0.25, "HelmetBlack")  # Combat Helmet
    b.add_box(0.0, 1.60, 0.14, 0.06, 0.06, 0.06, "NVGMount")      # NVG Mount Base
    # Dual NVG goggles
    b.add_cylinder(-0.045, 1.58, 0.14, 0.22, 0.018, segments=8, mat="NVGGoggles")
    b.add_cylinder(0.045, 1.58, 0.14, 0.22, 0.018, segments=8, mat="NVGGoggles")
    # 4. Comms Radio Antenna on back
    b.add_box(-0.14, 1.25, -0.16, 0.06, 0.14, 0.06, "PolymerBlack")
    b.add_cylinder(-0.14, 1.48, -0.16, -0.16, 0.005, segments=6, mat="SteelDark")
    return b

def generate_mtl(filepath):
    mtl_content = """# Weapons and Operator Materials
newmtl Gunmetal
Kd 0.22 0.24 0.26
Ks 0.6 0.65 0.7
Ns 45.0

newmtl GunmetalMatte
Kd 0.18 0.20 0.22
Ks 0.3 0.35 0.4
Ns 20.0

newmtl PolymerBlack
Kd 0.12 0.13 0.15
Ks 0.2 0.2 0.25
Ns 15.0

newmtl RubberBlack
Kd 0.08 0.08 0.09
Ks 0.1 0.1 0.1
Ns 5.0

newmtl Steel
Kd 0.55 0.58 0.62
Ks 0.8 0.85 0.9
Ns 80.0

newmtl SteelDark
Kd 0.32 0.34 0.38
Ks 0.7 0.75 0.8
Ns 60.0

newmtl Brass
Kd 0.88 0.72 0.24
Ks 0.9 0.8 0.3
Ns 70.0

newmtl ShotgunRed
Kd 0.82 0.15 0.12
Ks 0.4 0.4 0.4
Ns 25.0

newmtl LaserRed
Kd 0.95 0.1 0.1
Ke 1.0 0.1 0.1
Ks 0.2 0.2 0.2
Ns 10.0

newmtl SightGlass
Kd 0.2 0.8 0.9
d 0.5
Ks 0.9 0.9 0.9
Ns 100.0

newmtl HazardYellow
Kd 0.92 0.78 0.12
Ks 0.5 0.5 0.5
Ns 30.0

newmtl FlamePilot
Kd 1.0 0.5 0.1
Ke 1.0 0.55 0.15
Ks 0.2 0.2 0.2
Ns 10.0

newmtl CamoNavy
Kd 0.14 0.17 0.22
Ks 0.15 0.15 0.2
Ns 10.0

newmtl VestBlack
Kd 0.10 0.11 0.13
Ks 0.25 0.25 0.3
Ns 20.0

newmtl KneePads
Kd 0.07 0.08 0.09
Ks 0.3 0.3 0.35
Ns 25.0

newmtl BootsBlack
Kd 0.06 0.06 0.07
Ks 0.4 0.4 0.4
Ns 35.0

newmtl Balaclava
Kd 0.11 0.12 0.14
Ks 0.1 0.1 0.1
Ns 8.0

newmtl HelmetBlack
Kd 0.13 0.14 0.16
Ks 0.4 0.4 0.45
Ns 35.0

newmtl NVGMount
Kd 0.2 0.22 0.24
Ks 0.5 0.5 0.5
Ns 40.0

newmtl NVGGoggles
Kd 0.08 0.55 0.25
Ke 0.05 0.4 0.15
Ks 0.7 0.9 0.7
Ns 70.0

newmtl PouchCamo
Kd 0.18 0.21 0.18
Ks 0.15 0.15 0.15
Ns 10.0
"""
    with open(filepath, "w") as f:
        f.write(mtl_content)

def main():
    target_dir = "assets/models/weapons"
    os.makedirs(target_dir, exist_ok=True)
    
    mtl_path = os.path.join(target_dir, "weapons.mtl")
    generate_mtl(mtl_path)
    print(f"Generated {mtl_path}")
    
    weapons = {
        "pistol_3d.obj": build_pistol(),
        "shotgun_3d.obj": build_shotgun(),
        "rifle_3d.obj": build_rifle(),
        "flamethrower_3d.obj": build_flamethrower(),
        "minigun_3d.obj": build_minigun(),
        "swat_operator.obj": build_swat_operator()
    }
    
    for filename, builder in weapons.items():
        out_path = os.path.join(target_dir, filename)
        write_obj_file(out_path, builder.vertices, builder.normals, builder.uvs, builder.faces, material_lib="weapons.mtl")
        print(f"Generated {out_path} ({len(builder.vertices)} verts)")

if __name__ == "__main__":
    main()
