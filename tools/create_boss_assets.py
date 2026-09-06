import os
import math

BOSS_DIR = "assets/models/boss"
ENV_DIR = "assets/models/environment"
os.makedirs(BOSS_DIR, exist_ok=True)
os.makedirs(ENV_DIR, exist_ok=True)

class ObjBuilder:
    def __init__(self):
        self.vertices = []
        self.uvs = []
        self.normals = []
        self.faces = [] # list of (material_name, [ (v, uv, n) ... ])
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
        
        # Triangulate
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

    def add_cylinder(self, cx, cy, cz, r, h, segments=8):
        half_h = h * 0.5
        top_verts = []
        bot_verts = []
        for i in range(segments):
            ang = 2.0 * math.pi * i / segments
            x = cx + math.cos(ang) * r
            z = cz + math.sin(ang) * r
            top_verts.append(self.add_vertex(x, cy + half_h, z))
            bot_verts.append(self.add_vertex(x, cy - half_h, z))

        # Sides
        for i in range(segments):
            next_i = (i + 1) % segments
            ang = 2.0 * math.pi * (i + 0.5) / segments
            nx, nz = math.cos(ang), math.sin(ang)
            self.add_quad(
                bot_verts[i], bot_verts[next_i], top_verts[next_i], top_verts[i],
                (i / segments, 0), ((i + 1) / segments, 0), ((i + 1) / segments, 1), (i / segments, 1),
                (nx, 0, nz)
            )

        # Caps
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

    def add_spike(self, bx, by, bz, tx, ty, tz, base_r, segments=6):
        """Conical spike pointing from base to tip."""
        base_verts = []
        # Find orthogonal vectors for circle
        dx, dy, dz = tx - bx, ty - by, tz - bz
        l = math.sqrt(dx*dx + dy*dy + dz*dz)
        if l < 1e-5: return
        ux, uy, uz = dx/l, dy/l, dz/l
        vx, vy, vz = (-uy, ux, 0) if abs(uz) < 0.9 else (0, -uz, uy)
        vl = math.sqrt(vx*vx + vy*vy + vz*vz)
        vx, vy, vz = vx/vl, vy/vl, vz/vl
        wx = uy*vz - uz*vy
        wy = uz*vx - ux*vz
        wz = ux*vy - uy*vx

        for i in range(segments):
            ang = 2.0 * math.pi * i / segments
            c, s = math.cos(ang) * base_r, math.sin(ang) * base_r
            px = bx + vx * c + wx * s
            py = by + vy * c + wy * s
            pz = bz + vz * c + wz * s
            base_verts.append(self.add_vertex(px, py, pz))

        tip_v = self.add_vertex(tx, ty, tz)
        uv_tip = self.add_uv(0.5, 1.0)
        for i in range(segments):
            next_i = (i + 1) % segments
            uv1 = self.add_uv(i/segments, 0.0)
            uv2 = self.add_uv((i+1)/segments, 0.0)
            # normal
            ang = 2.0 * math.pi * (i + 0.5) / segments
            nx = vx * math.cos(ang) + wx * math.sin(ang) + ux * 0.3
            ny = vy * math.cos(ang) + wy * math.sin(ang) + uy * 0.3
            nz = vz * math.cos(ang) + wz * math.sin(ang) + uz * 0.3
            idx_n = self.add_normal(nx, ny, nz)
            self.faces.append((self.current_material, [
                (base_verts[i], uv1, idx_n),
                (base_verts[next_i], uv2, idx_n),
                (tip_v, uv_tip, idx_n)
            ]))

    def write_obj(self, filename, mtl_name=None):
        with open(filename, 'w') as f:
            f.write("# Generated Boss Asset\n")
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

# --- 1. GOLIATH BOSS (Bio-Containment Subject 0) ---
def build_goliath():
    b = ObjBuilder()

    # Materials:
    # Flesh: Dark bruised mutant skin with armored hide (#2b2e34)
    # ChitinArmor: Hard black carapace plates on shoulders/back (#1a1b1e)
    # MoltenCore: Flaming pulsing chest core (#ff4500 / emissive orange)
    # BoneSpikes: Bleached jagged bone blades and horn spikes (#d8cca3)
    # WeakPoint: Pulsing crimson-amber back tumor with exposed arteries (#ff1133)

    # LOWER BODY / LEGS
    b.set_material("ChitinArmor")
    # Left leg
    b.add_box(-0.9, 0.9, 0.0, 0.9, 1.8, 0.9)
    b.add_box(-0.9, 0.2, 0.2, 1.05, 0.4, 1.2) # foot claw
    # Right leg
    b.add_box(0.9, 0.9, 0.0, 0.9, 1.8, 0.9)
    b.add_box(0.9, 0.2, 0.2, 1.05, 0.4, 1.2)

    # PELVIS & MASSIVE TORSO
    b.set_material("Flesh")
    b.add_box(0.0, 2.1, 0.0, 2.2, 0.9, 1.5) # Pelvis
    b.add_box(0.0, 3.1, 0.15, 2.7, 1.4, 1.9) # Abdomen & Torso

    # DORSAL HUNCH & SPINAL PLATES
    b.set_material("ChitinArmor")
    b.add_box(0.0, 3.8, -0.35, 2.4, 1.3, 1.4) # Hunched upper back
    # Spinal Chitin Ridges
    for sp_z in range(-2, 3):
        b.add_box(0.0, 3.4 + sp_z * 0.35, -0.95, 0.35, 0.35, 0.5)

    # WEAK POINT BACK (Phase 3 Blister / Exposed Core Vent)
    b.set_material("WeakPoint")
    # A bulbous exposed cluster of pulsing organ tissue centered on the mid-upper back
    b.add_box(0.0, 3.4, -0.85, 1.1, 0.9, 0.4)
    b.add_cylinder(0.0, 3.4, -0.9, 0.45, 0.4, 8)

    # MOLTEN CORE CHEST (Phase 1-3 glowing heart)
    b.set_material("MoltenCore")
    b.add_box(0.0, 3.2, 1.05, 1.1, 1.1, 0.35)
    b.add_cylinder(0.0, 3.2, 1.12, 0.45, 0.25, 8)

    # HEAD & HORNS
    b.set_material("ChitinArmor")
    b.add_box(0.0, 4.3, 0.55, 1.1, 1.0, 1.2) # Head
    b.set_material("MoltenCore")
    # Burning eyes / jaw vents
    b.add_box(-0.25, 4.35, 1.15, 0.22, 0.15, 0.15)
    b.add_box(0.25, 4.35, 1.15, 0.22, 0.15, 0.15)
    b.add_box(0.0, 4.0, 1.12, 0.6, 0.25, 0.2) # Maw
    # Head horns
    b.set_material("BoneSpikes")
    b.add_spike(-0.45, 4.7, 0.55, -0.85, 5.4, 0.35, 0.18, 6)
    b.add_spike(0.45, 4.7, 0.55, 0.85, 5.4, 0.35, 0.18, 6)

    # LEFT ARM (Predatory claw)
    b.set_material("Flesh")
    b.add_box(-1.8, 3.5, 0.2, 0.8, 0.9, 0.9) # Shoulder
    b.add_box(-2.1, 2.6, 0.35, 0.65, 1.3, 0.7) # Forearm
    b.set_material("BoneSpikes")
    # 3 Talons
    b.add_spike(-2.25, 1.9, 0.45, -2.4, 1.2, 0.6, 0.12, 5)
    b.add_spike(-2.1, 1.9, 0.55, -2.1, 1.15, 0.8, 0.12, 5)
    b.add_spike(-1.95, 1.9, 0.45, -1.8, 1.2, 0.6, 0.12, 5)

    # RIGHT ARM (MASSIVE ASYMMETRIC SPIKED CRUSHER)
    # Huge shoulder
    b.set_material("ChitinArmor")
    b.add_box(2.0, 3.6, 0.2, 1.3, 1.3, 1.4)
    # Shoulder spikes
    b.set_material("BoneSpikes")
    b.add_spike(2.4, 4.2, 0.2, 3.3, 5.3, 0.3, 0.28, 6)
    b.add_spike(2.2, 4.2, -0.4, 3.1, 5.0, -0.7, 0.24, 6)
    b.add_spike(2.3, 4.1, 0.7, 3.2, 4.9, 1.0, 0.24, 6)

    # Enormous Forearm
    b.set_material("Flesh")
    b.add_box(2.4, 2.3, 0.5, 1.2, 1.7, 1.3)
    b.set_material("MoltenCore")
    # Glowing vein slit on forearm
    b.add_box(2.4, 2.3, 1.15, 0.4, 1.2, 0.1)

    # Forearm Bone Blades
    b.set_material("BoneSpikes")
    b.add_spike(2.9, 2.7, 0.5, 4.1, 2.9, 0.6, 0.22, 6)
    b.add_spike(2.9, 2.1, 0.5, 4.0, 2.0, 0.6, 0.22, 6)
    b.add_spike(2.9, 1.5, 0.5, 3.7, 1.3, 0.6, 0.18, 6)

    # Giant Fist / Cleaver Claws
    b.set_material("ChitinArmor")
    b.add_box(2.4, 1.1, 0.65, 1.3, 0.9, 1.2)
    b.set_material("BoneSpikes")
    b.add_spike(2.0, 0.8, 1.1, 2.0, 0.1, 1.6, 0.16, 5)
    b.add_spike(2.4, 0.8, 1.2, 2.4, 0.0, 1.8, 0.20, 5)
    b.add_spike(2.8, 0.8, 1.1, 2.8, 0.1, 1.6, 0.16, 5)

    b.write_obj(f"{BOSS_DIR}/goliath_boss.obj", "boss.mtl")
    print("[OK] Built Goliath Boss Model")

# --- 2. PLAGUE HOUND (Phase 2 Minion) ---
def build_plague_hound():
    b = ObjBuilder()

    # Materials:
    # HoundSkin: Sickly dark green-grey rotting flesh (#3b4038)
    # HoundBones: Exposed ribcage and spikes (#c4b898)
    # HoundEyes: Glowing infected pustule (#ff3300)

    # Body
    b.set_material("HoundSkin")
    b.add_box(0.0, 0.55, 0.0, 0.45, 0.42, 1.1)
    b.add_box(0.0, 0.72, 0.35, 0.52, 0.48, 0.6) # Shoulders

    # Exposed Ribs & Spikes
    b.set_material("HoundBones")
    b.add_spike(-0.15, 0.9, 0.4, -0.25, 1.25, 0.35, 0.06, 4)
    b.add_spike(0.15, 0.9, 0.4, 0.25, 1.25, 0.35, 0.06, 4)
    b.add_spike(0.0, 0.8, 0.0, 0.0, 1.15, -0.05, 0.05, 4)
    b.add_spike(0.0, 0.75, -0.3, 0.0, 1.05, -0.35, 0.05, 4)

    # Head & Fangs
    b.set_material("HoundSkin")
    b.add_box(0.0, 0.7, 0.85, 0.32, 0.3, 0.5) # Head
    b.add_box(0.0, 0.62, 1.15, 0.22, 0.18, 0.4) # Snout
    b.set_material("HoundEyes")
    b.add_box(-0.12, 0.76, 0.95, 0.08, 0.08, 0.08)
    b.add_box(0.12, 0.76, 0.95, 0.08, 0.08, 0.08)
    b.set_material("HoundBones")
    b.add_spike(-0.09, 0.58, 1.25, -0.09, 0.4, 1.27, 0.03, 4)
    b.add_spike(0.09, 0.58, 1.25, 0.09, 0.4, 1.27, 0.03, 4)

    # Front Legs
    b.set_material("HoundSkin")
    b.add_box(-0.24, 0.3, 0.4, 0.15, 0.6, 0.18)
    b.add_box(0.24, 0.3, 0.4, 0.15, 0.6, 0.18)

    # Back Legs
    b.add_box(-0.22, 0.32, -0.4, 0.16, 0.64, 0.22)
    b.add_box(0.22, 0.32, -0.4, 0.16, 0.64, 0.22)

    b.write_obj(f"{BOSS_DIR}/plague_hound.obj", "boss.mtl")
    print("[OK] Built Plague Hound Model")

# --- 3. BOULDER DEBRIS (Phase 1 Hurled Rock) ---
def build_boulder():
    b = ObjBuilder()
    b.set_material("RockDebris")

    # Faceted jagged boulder
    b.add_box(0.0, 0.0, 0.0, 1.6, 1.4, 1.6)
    b.add_box(0.0, 0.0, 0.0, 1.3, 1.8, 1.3)
    # Beveled jagged extrusions
    b.add_box(0.3, 0.3, 0.3, 1.2, 1.2, 1.2)
    b.add_box(-0.3, -0.2, 0.2, 1.1, 1.1, 1.1)

    b.write_obj(f"{BOSS_DIR}/boulder.obj", "boss.mtl")
    print("[OK] Built Boulder Model")

# --- 4. REINFORCED BLAST GATE (Arena Seal) ---
def build_blast_gate():
    b = ObjBuilder()
    b.set_material("BlastGateSteel")

    # Gate posts / frame
    b.add_box(-3.2, 2.5, 0.0, 0.7, 5.0, 0.8)
    b.add_box(3.2, 2.5, 0.0, 0.7, 5.0, 0.8)
    b.add_box(0.0, 4.8, 0.0, 7.0, 0.6, 0.9)

    # Left Sliding Door
    b.set_material("HazardGate")
    b.add_box(-1.45, 2.2, 0.0, 2.8, 4.2, 0.35)
    # Right Sliding Door
    b.add_box(1.45, 2.2, 0.0, 2.8, 4.2, 0.35)

    # Interlocking teeth & pistons
    b.set_material("BlastGateSteel")
    b.add_box(0.0, 1.5, 0.2, 0.35, 0.4, 0.2)
    b.add_box(0.0, 2.5, 0.2, 0.35, 0.4, 0.2)
    b.add_box(0.0, 3.5, 0.2, 0.35, 0.4, 0.2)

    b.write_obj(f"{ENV_DIR}/blast_gate.obj", "boss.mtl")
    print("[OK] Built Blast Gate Model")

# --- 5. BOSS MTL FILE ---
def build_mtl():
    mtl_content = """# Boss Materials
newmtl Flesh
Kd 0.18 0.19 0.21
Ka 0.1 0.1 0.1
Ks 0.1 0.1 0.1
Ns 10

newmtl ChitinArmor
Kd 0.08 0.09 0.11
Ka 0.05 0.05 0.05
Ks 0.35 0.35 0.4
Ns 45

newmtl MoltenCore
Kd 1.0 0.28 0.04
Ka 1.0 0.3 0.05
Ke 1.0 0.35 0.05
Ks 0.2 0.2 0.2
Ns 20

newmtl BoneSpikes
Kd 0.82 0.78 0.68
Ka 0.4 0.4 0.35
Ks 0.2 0.2 0.2
Ns 15

newmtl WeakPoint
Kd 0.95 0.08 0.15
Ka 0.8 0.05 0.1
Ke 0.9 0.1 0.2
Ks 0.4 0.1 0.1
Ns 50

newmtl HoundSkin
Kd 0.22 0.24 0.20
Ka 0.1 0.1 0.1
Ks 0.1 0.1 0.1
Ns 10

newmtl HoundBones
Kd 0.75 0.72 0.62
Ka 0.3 0.3 0.25
Ks 0.15 0.15 0.15
Ns 15

newmtl HoundEyes
Kd 1.0 0.1 0.0
Ke 1.0 0.2 0.0
Ka 0.5 0.0 0.0
Ks 0.5 0.5 0.5
Ns 30

newmtl RockDebris
Kd 0.28 0.26 0.24
Ka 0.15 0.14 0.13
Ks 0.05 0.05 0.05
Ns 5

newmtl BlastGateSteel
Kd 0.18 0.20 0.23
Ka 0.1 0.1 0.12
Ks 0.5 0.5 0.55
Ns 60

newmtl HazardGate
Kd 0.75 0.55 0.12
Ka 0.3 0.25 0.05
Ks 0.3 0.3 0.3
Ns 30
"""
    with open(f"{BOSS_DIR}/boss.mtl", "w") as f:
        f.write(mtl_content)
    with open(f"{ENV_DIR}/boss.mtl", "w") as f:
        f.write(mtl_content)
    print("[OK] Built boss.mtl Materials")

if __name__ == "__main__":
    build_mtl()
    build_goliath()
    build_plague_hound()
    build_boulder()
    build_blast_gate()
