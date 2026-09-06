import os
import math

ENV_DIR = "assets/models/environment"
PROPS_DIR = "assets/models/props"
os.makedirs(ENV_DIR, exist_ok=True)
os.makedirs(PROPS_DIR, exist_ok=True)

class ObjBuilder:
    def __init__(self):
        self.vertices = []
        self.uvs = []
        self.normals = []
        self.faces = []
        self.current_material = "default"

    def set_material(self, mat_name):
        self.current_material = mat_name

    def add_vertex(self, x, y, z):
        self.vertices.append((x, y, z))
        return len(self.vertices)

    def add_uv(self, u, v):
        self.uvs.append((u, v))
        return len(self.uvs)

    def add_normal(self, nx, ny, nz):
        l = math.sqrt(nx*nx + ny*ny + nz*nz)
        if l > 1e-6:
            nx, ny, nz = nx/l, ny/l, nz/l
        self.normals.append((nx, ny, nz))
        return len(self.normals)

    def add_quad(self, v1, v2, v3, v4, uv1, uv2, uv3, uv4, n):
        idx_n = self.add_normal(*n)
        i_uv1 = self.add_uv(*uv1)
        i_uv2 = self.add_uv(*uv2)
        i_uv3 = self.add_uv(*uv3)
        i_uv4 = self.add_uv(*uv4)
        
        self.faces.append((self.current_material, [
            (v1, i_uv1, idx_n),
            (v2, i_uv2, idx_n),
            (v3, i_uv3, idx_n)
        ]))
        self.faces.append((self.current_material, [
            (v1, i_uv1, idx_n),
            (v3, i_uv3, idx_n),
            (v4, i_uv4, idx_n)
        ]))

    def add_box(self, cx, cy, cz, sx, sy, sz):
        hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
        # Front (+Z)
        v1 = self.add_vertex(cx - hx, cy - hy, cz + hz)
        v2 = self.add_vertex(cx + hx, cy - hy, cz + hz)
        v3 = self.add_vertex(cx + hx, cy + hy, cz + hz)
        v4 = self.add_vertex(cx - hx, cy + hy, cz + hz)
        self.add_quad(v1, v2, v3, v4, (0,0), (1,0), (1,1), (0,1), (0, 0, 1))

        # Back (-Z)
        v5 = self.add_vertex(cx + hx, cy - hy, cz - hz)
        v6 = self.add_vertex(cx - hx, cy - hy, cz - hz)
        v7 = self.add_vertex(cx - hx, cy + hy, cz - hz)
        v8 = self.add_vertex(cx + hx, cy + hy, cz - hz)
        self.add_quad(v5, v6, v7, v8, (0,0), (1,0), (1,1), (0,1), (0, 0, -1))

        # Right (+X)
        v9 = self.add_vertex(cx + hx, cy - hy, cz + hz)
        v10 = self.add_vertex(cx + hx, cy - hy, cz - hz)
        v11 = self.add_vertex(cx + hx, cy + hy, cz - hz)
        v12 = self.add_vertex(cx + hx, cy + hy, cz + hz)
        self.add_quad(v9, v10, v11, v12, (0,0), (1,0), (1,1), (0,1), (1, 0, 0))

        # Left (-X)
        v13 = self.add_vertex(cx - hx, cy - hy, cz - hz)
        v14 = self.add_vertex(cx - hx, cy - hy, cz + hz)
        v15 = self.add_vertex(cx - hx, cy + hy, cz + hz)
        v16 = self.add_vertex(cx - hx, cy + hy, cz - hz)
        self.add_quad(v13, v14, v15, v16, (0,0), (1,0), (1,1), (0,1), (-1, 0, 0))

        # Top (+Y)
        v17 = self.add_vertex(cx - hx, cy + hy, cz + hz)
        v18 = self.add_vertex(cx + hx, cy + hy, cz + hz)
        v19 = self.add_vertex(cx + hx, cy + hy, cz - hz)
        v20 = self.add_vertex(cx - hx, cy + hy, cz - hz)
        self.add_quad(v17, v18, v19, v20, (0,0), (1,0), (1,1), (0,1), (0, 1, 0))

        # Bottom (-Y)
        v21 = self.add_vertex(cx - hx, cy - hy, cz - hz)
        v22 = self.add_vertex(cx + hx, cy - hy, cz - hz)
        v23 = self.add_vertex(cx + hx, cy - hy, cz + hz)
        v24 = self.add_vertex(cx - hx, cy - hy, cz + hz)
        self.add_quad(v21, v22, v23, v24, (0,0), (1,0), (1,1), (0,1), (0, -1, 0))

    def add_cylinder(self, cx, cy, cz, r, h, segments=12):
        half_h = h * 0.5
        top_verts = []
        bot_verts = []
        for i in range(segments):
            ang = 2.0 * math.pi * i / segments
            x = cx + math.cos(ang) * r
            z = cz + math.sin(ang) * r
            top_verts.append(self.add_vertex(x, cy + half_h, z))
            bot_verts.append(self.add_vertex(x, cy - half_h, z))

        for i in range(segments):
            next_i = (i + 1) % segments
            ang = 2.0 * math.pi * (i + 0.5) / segments
            nx, nz = math.cos(ang), math.sin(ang)
            self.add_quad(
                bot_verts[i], bot_verts[next_i], top_verts[next_i], top_verts[i],
                (i / segments, 0), ((i + 1) / segments, 0), ((i + 1) / segments, 1), (i / segments, 1),
                (nx, 0, nz)
            )

        center_top = self.add_vertex(cx, cy + half_h, cz)
        center_bot = self.add_vertex(cx, cy - half_h, cz)
        n_up = self.add_normal(0, 1, 0)
        n_down = self.add_normal(0, -1, 0)
        uv_c = self.add_uv(0.5, 0.5)
        for i in range(segments):
            next_i = (i + 1) % segments
            uv1 = self.add_uv(0.5 + 0.5 * math.cos(2*math.pi*i/segments), 0.5 + 0.5 * math.sin(2*math.pi*i/segments))
            uv2 = self.add_uv(0.5 + 0.5 * math.cos(2*math.pi*next_i/segments), 0.5 + 0.5 * math.sin(2*math.pi*next_i/segments))
            self.faces.append((self.current_material, [
                (center_top, uv_c, n_up),
                (top_verts[i], uv1, n_up),
                (top_verts[next_i], uv2, n_up)
            ]))
            self.faces.append((self.current_material, [
                (center_bot, uv_c, n_down),
                (bot_verts[next_i], uv2, n_down),
                (bot_verts[i], uv1, n_down)
            ]))

    def write_obj(self, filename, mtl_name=None):
        with open(filename, 'w') as f:
            f.write("# Generated Campaign Asset\n")
            if mtl_name:
                f.write(f"mtllib {mtl_name}\n")
            for x, y, z in self.vertices:
                f.write(f"v {x:.4f} {y:.4f} {z:.4f}\n")
            for u, v in self.uvs:
                f.write(f"vt {u:.4f} {v:.4f}\n")
            for nx, ny, nz in self.normals:
                f.write(f"vn {nx:.4f} {ny:.4f} {nz:.4f}\n")

            cur_m = None
            for mat, face in self.faces:
                if mat != cur_m:
                    f.write(f"usemtl {mat}\n")
                    cur_m = mat
                f.write("f " + " ".join(f"{v}/{uv}/{n}" for v, uv, n in face) + "\n")

# --- 1. EXTRACTION HELIPAD ---
def build_extraction_pad():
    b = ObjBuilder()
    b.set_material("PadSteel")
    # Base octagonal/round landing platform
    b.add_cylinder(0.0, 0.05, 0.0, 3.5, 0.1, segments=12)
    
    # Outer hazard rim
    b.set_material("PadHazard")
    for i in range(8):
        ang = 2.0 * math.pi * i / 8
        px = math.cos(ang) * 3.3
        pz = math.sin(ang) * 3.3
        b.add_box(px, 0.15, pz, 0.35, 0.25, 0.35)
    
    # Center Landing "H" Emblem
    b.set_material("PadGlow")
    b.add_box(-0.8, 0.11, 0.0, 0.3, 0.02, 2.0)
    b.add_box(0.8, 0.11, 0.0, 0.3, 0.02, 2.0)
    b.add_box(0.0, 0.11, 0.0, 1.4, 0.02, 0.35)

    b.write_obj(f"{ENV_DIR}/extraction_pad.obj", "campaign.mtl")
    print("[OK] Built extraction_pad.obj")

# --- 2. BATTERY CELL ---
def build_battery_cell():
    b = ObjBuilder()
    b.set_material("HeavySteel")
    # Outer protective cage
    b.add_box(0.0, 0.45, 0.0, 0.5, 0.9, 0.5)
    
    # Glowing energy core
    b.set_material("EnergyBlue")
    b.add_cylinder(0.0, 0.45, 0.0, 0.18, 0.8, segments=8)
    
    # Terminals
    b.set_material("GoldTerminal")
    b.add_cylinder(-0.12, 0.95, 0.0, 0.05, 0.12, segments=6)
    b.add_cylinder(0.12, 0.95, 0.0, 0.05, 0.12, segments=6)

    b.write_obj(f"{PROPS_DIR}/battery_cell.obj", "campaign.mtl")
    print("[OK] Built battery_cell.obj")

# --- 3. RAIL CONSOLE SWITCH ---
def build_rail_console():
    b = ObjBuilder()
    b.set_material("HeavySteel")
    # Console pedestal
    b.add_box(0.0, 0.6, 0.0, 0.8, 1.2, 0.6)
    b.add_box(0.0, 1.15, 0.1, 0.75, 0.3, 0.5) # Angled top
    
    # Terminal Screen
    b.set_material("ScreenGreen")
    b.add_box(0.0, 1.25, 0.15, 0.55, 0.25, 0.05)
    
    # Heavy lever
    b.set_material("LeverYellow")
    b.add_box(0.24, 1.32, 0.05, 0.08, 0.32, 0.08)

    b.write_obj(f"{PROPS_DIR}/rail_console.obj", "campaign.mtl")
    print("[OK] Built rail_console.obj")

# --- 4. CHEMICAL VALVE ---
def build_chemical_valve():
    b = ObjBuilder()
    b.set_material("PipeSteel")
    # Pipes
    b.add_cylinder(0.0, 0.8, 0.0, 0.2, 1.6, segments=8)
    b.add_box(0.0, 0.8, 0.0, 0.6, 0.6, 0.6)
    
    # Valve Wheel
    b.set_material("ValveRed")
    b.add_cylinder(0.0, 0.8, 0.38, 0.35, 0.08, segments=10)
    b.add_cylinder(0.0, 0.8, 0.38, 0.08, 0.15, segments=6)

    b.write_obj(f"{PROPS_DIR}/chemical_valve.obj", "campaign.mtl")
    print("[OK] Built chemical_valve.obj")

# --- 5. MASTER KEYCARD & PODIUM ---
def build_master_keycard():
    b = ObjBuilder()
    b.set_material("HeavySteel")
    # Security Pedestal
    b.add_cylinder(0.0, 0.5, 0.0, 0.35, 1.0, segments=8)
    
    # Keycard
    b.set_material("CardGold")
    b.add_box(0.0, 1.05, 0.0, 0.32, 0.04, 0.48)
    b.set_material("ScreenGreen")
    b.add_box(0.0, 1.07, 0.0, 0.15, 0.02, 0.2)

    b.write_obj(f"{PROPS_DIR}/master_keycard.obj", "campaign.mtl")
    print("[OK] Built master_keycard.obj")

# --- 6. RADIO TOWER TRANSMITTER ---
def build_radio_tower():
    b = ObjBuilder()
    b.set_material("HeavySteel")
    # Base terminal
    b.add_box(0.0, 0.6, 0.0, 1.2, 1.2, 1.0)
    
    # Tower Mast
    b.set_material("PipeSteel")
    b.add_cylinder(0.0, 2.5, 0.0, 0.12, 2.6, segments=6)
    
    # Parabolic Dish / Transceiver
    b.set_material("DishWhite")
    b.add_cylinder(0.0, 3.6, 0.25, 0.6, 0.15, segments=10)
    
    # Beacon light tip
    b.set_material("BeaconRed")
    b.add_box(0.0, 4.0, 0.0, 0.15, 0.25, 0.15)

    b.write_obj(f"{PROPS_DIR}/radio_tower.obj", "campaign.mtl")
    print("[OK] Built radio_tower.obj")

def build_mtl():
    mtl = """# Campaign Props & Environment Materials
newmtl PadSteel
Kd 0.22 0.24 0.26
Ka 0.1 0.1 0.12
Ks 0.4 0.4 0.45
Ns 35

newmtl PadHazard
Kd 0.85 0.72 0.15
Ka 0.3 0.25 0.05
Ks 0.2 0.2 0.2
Ns 20

newmtl PadGlow
Kd 0.1 0.95 0.4
Ka 0.1 0.95 0.4
Ke 0.1 0.95 0.4
Ks 0.5 0.5 0.5
Ns 60

newmtl HeavySteel
Kd 0.18 0.2 0.22
Ka 0.1 0.1 0.1
Ks 0.35 0.35 0.4
Ns 30

newmtl EnergyBlue
Kd 0.1 0.6 1.0
Ka 0.2 0.7 1.0
Ke 0.3 0.8 1.0
Ks 0.8 0.8 0.9
Ns 80

newmtl GoldTerminal
Kd 0.9 0.75 0.2
Ka 0.4 0.3 0.1
Ks 0.7 0.6 0.2
Ns 50

newmtl ScreenGreen
Kd 0.15 0.85 0.35
Ke 0.2 0.9 0.4
Ka 0.1 0.4 0.15
Ks 0.5 0.5 0.5
Ns 40

newmtl LeverYellow
Kd 0.9 0.65 0.1
Ka 0.3 0.2 0.05
Ks 0.4 0.4 0.4
Ns 25

newmtl PipeSteel
Kd 0.35 0.36 0.38
Ka 0.15 0.15 0.16
Ks 0.5 0.5 0.55
Ns 40

newmtl ValveRed
Kd 0.85 0.15 0.12
Ka 0.3 0.05 0.05
Ks 0.3 0.3 0.3
Ns 25

newmtl CardGold
Kd 0.95 0.82 0.25
Ke 0.3 0.25 0.05
Ka 0.4 0.35 0.1
Ks 0.6 0.5 0.2
Ns 45

newmtl DishWhite
Kd 0.85 0.87 0.9
Ka 0.4 0.4 0.42
Ks 0.3 0.3 0.3
Ns 30

newmtl BeaconRed
Kd 1.0 0.15 0.15
Ke 1.0 0.2 0.2
Ka 0.5 0.05 0.05
Ks 0.8 0.8 0.8
Ns 70
"""
    with open(f"{ENV_DIR}/campaign.mtl", "w") as f:
        f.write(mtl)
    with open(f"{PROPS_DIR}/campaign.mtl", "w") as f:
        f.write(mtl)
    print("[OK] Built campaign.mtl")

if __name__ == "__main__":
    build_mtl()
    build_extraction_pad()
    build_battery_cell()
    build_rail_console()
    build_chemical_valve()
    build_master_keycard()
    build_radio_tower()
