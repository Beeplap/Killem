import os
import math

OUTPUT_DIR = "assets/models/environment"
os.makedirs(OUTPUT_DIR, exist_ok=True)

class ObjBuilder:
    def __init__(self):
        self.vertices = []
        self.uvs = []
        self.normals = []
        self.faces = []

    def add_vertex(self, x, y, z):
        self.vertices.append((x, y, z))
        return len(self.vertices)

    def add_uv(self, u, v):
        self.uvs.append((u, v))
        return len(self.uvs)

    def add_normal(self, nx, ny, nz):
        self.normals.append((nx, ny, nz))
        return len(self.normals)

    def add_face(self, v_indices, uv_indices, n_indices):
        # Triangulate if polygon has 4 vertices
        if len(v_indices) == 4:
            self.faces.append((
                (v_indices[0], uv_indices[0], n_indices[0]),
                (v_indices[1], uv_indices[1], n_indices[1]),
                (v_indices[2], uv_indices[2], n_indices[2])
            ))
            self.faces.append((
                (v_indices[0], uv_indices[0], n_indices[0]),
                (v_indices[2], uv_indices[2], n_indices[2]),
                (v_indices[3], uv_indices[3], n_indices[3])
            ))
        elif len(v_indices) == 3:
            self.faces.append((
                (v_indices[0], uv_indices[0], n_indices[0]),
                (v_indices[1], uv_indices[1], n_indices[1]),
                (v_indices[2], uv_indices[2], n_indices[2])
            ))

    def add_box(self, cx, cy, cz, sx, sy, sz, u_scale=1.0, v_scale=1.0):
        """Add an axis-aligned box with normals and UVs."""
        hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
        
        # 6 Faces: +Z, -Z, +X, -X, +Y, -Y
        faces_def = [
            # (+Z, Front)
            ([ (cx-hx, cy-hy, cz+hz), (cx+hx, cy-hy, cz+hz), (cx+hx, cy+hy, cz+hz), (cx-hx, cy+hy, cz+hz) ], (0, 0, 1)),
            # (-Z, Back)
            ([ (cx+hx, cy-hy, cz-hz), (cx-hx, cy-hy, cz-hz), (cx-hx, cy+hy, cz-hz), (cx+hx, cy+hy, cz-hz) ], (0, 0, -1)),
            # (+X, Right)
            ([ (cx+hx, cy-hy, cz+hz), (cx+hx, cy-hy, cz-hz), (cx+hx, cy+hy, cz-hz), (cx+hx, cy+hy, cz+hz) ], (1, 0, 0)),
            # (-X, Left)
            ([ (cx-hx, cy-hy, cz-hz), (cx-hx, cy-hy, cz+hz), (cx-hx, cy+hy, cz+hz), (cx-hx, cy+hy, cz-hz) ], (-1, 0, 0)),
            # (+Y, Top)
            ([ (cx-hx, cy+hy, cz+hz), (cx+hx, cy+hy, cz+hz), (cx+hx, cy+hy, cz-hz), (cx-hx, cy+hy, cz-hz) ], (0, 1, 0)),
            # (-Y, Bottom)
            ([ (cx-hx, cy-hy, cz-hz), (cx+hx, cy-hy, cz-hz), (cx+hx, cy-hy, cz+hz), (cx-hx, cy-hy, cz+hz) ], (0, -1, 0)),
        ]
        
        uv_coords = [(0.0, 0.0), (u_scale, 0.0), (u_scale, v_scale), (0.0, v_scale)]
        uv_idx = [self.add_uv(u, v) for u, v in uv_coords]
        
        for verts, norm in faces_def:
            n_idx = self.add_normal(*norm)
            v_idx = [self.add_vertex(*v) for v in verts]
            self.add_face(v_idx, uv_idx, [n_idx]*4)

    def add_cylinder(self, cx, cy, cz, radius, height, segments=12):
        """Add a vertical cylinder."""
        hy = height * 0.5
        top_center = self.add_vertex(cx, cy + hy, cz)
        bot_center = self.add_vertex(cx, cy - hy, cz)
        top_norm = self.add_normal(0, 1, 0)
        bot_norm = self.add_normal(0, -1, 0)
        uv_c = self.add_uv(0.5, 0.5)

        top_ring = []
        bot_ring = []
        side_norms = []
        side_uvs_top = []
        side_uvs_bot = []

        for i in range(segments + 1):
            a = (i / segments) * math.tau
            cos_a = math.cos(a)
            sin_a = math.sin(a)
            top_ring.append(self.add_vertex(cx + cos_a * radius, cy + hy, cz + sin_a * radius))
            bot_ring.append(self.add_vertex(cx + cos_a * radius, cy - hy, cz + sin_a * radius))
            side_norms.append(self.add_normal(cos_a, 0, sin_a))
            u = i / segments
            side_uvs_top.append(self.add_uv(u, 1.0))
            side_uvs_bot.append(self.add_uv(u, 0.0))

        # Side quads & caps
        for i in range(segments):
            # Side
            self.add_face(
                [bot_ring[i], bot_ring[i+1], top_ring[i+1], top_ring[i]],
                [side_uvs_bot[i], side_uvs_bot[i+1], side_uvs_top[i+1], side_uvs_top[i]],
                [side_norms[i], side_norms[i+1], side_norms[i+1], side_norms[i]]
            )
            # Top cap
            self.add_face(
                [top_center, top_ring[i+1], top_ring[i]],
                [uv_c, side_uvs_top[i+1], side_uvs_top[i]],
                [top_norm, top_norm, top_norm]
            )
            # Bottom cap
            self.add_face(
                [bot_center, bot_ring[i], bot_ring[i+1]],
                [uv_c, side_uvs_bot[i], side_uvs_bot[i+1]],
                [bot_norm, bot_norm, bot_norm]
            )

    def write_file(self, filepath):
        with open(filepath, "w") as f:
            f.write("# Wavefront OBJ generated for Godot 4 3D\n")
            for v in self.vertices:
                f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
            for vt in self.uvs:
                f.write(f"vt {vt[0]:.4f} {vt[1]:.4f}\n")
            for vn in self.normals:
                f.write(f"vn {vn[0]:.4f} {vn[1]:.4f} {vn[2]:.4f}\n")
            for face in self.faces:
                f.write("f " + " ".join([f"{idx[0]}/{idx[1]}/{idx[2]}" for idx in face]) + "\n")
        print(f"Saved: {filepath}")

# 1. Railway Track Segment (6m length)
def build_railway_track():
    obj = ObjBuilder()
    track_len = 6.0
    gauge = 1.435 # Standard gauge between rail heads
    
    # Gravel Ballast Bed (trapezoidal berm)
    obj.add_box(0, 0.08, 0, 2.4, 0.16, track_len, u_scale=2.0, v_scale=6.0)
    
    # Wooden Crossties / Sleepers (every 0.75m)
    num_sleepers = 8
    for i in range(num_sleepers):
        z = -track_len * 0.5 + (i + 0.5) * (track_len / num_sleepers)
        # Wooden tie (2.2m x 0.16m x 0.22m)
        obj.add_box(0, 0.20, z, 2.2, 0.12, 0.24, u_scale=1.0, v_scale=1.0)
        # Steel tie plates under rails
        obj.add_box(-gauge * 0.5, 0.27, z, 0.22, 0.02, 0.26)
        obj.add_box(gauge * 0.5, 0.27, z, 0.22, 0.02, 0.26)
        
    # Dual Steel Rails (Base, Web, Head)
    for x in [-gauge * 0.5, gauge * 0.5]:
        # Rail Base Flange
        obj.add_box(x, 0.29, 0, 0.14, 0.02, track_len, v_scale=track_len)
        # Rail Vertical Web
        obj.add_box(x, 0.35, 0, 0.03, 0.10, track_len, v_scale=track_len)
        # Rail Head
        obj.add_box(x, 0.42, 0, 0.07, 0.04, track_len, v_scale=track_len)
        
    obj.write_file(f"{OUTPUT_DIR}/railway_track.obj")

# 2. Concrete Blast Wall (3.5m length, 2.2m height)
def build_concrete_blast_wall():
    obj = ObjBuilder()
    # Wide base foot (stability foot)
    obj.add_box(0, 0.15, 0, 0.9, 0.3, 3.5, u_scale=3.5, v_scale=0.5)
    # Main vertical wall body
    obj.add_box(0, 1.25, 0, 0.38, 2.0, 3.5, u_scale=3.5, v_scale=2.0)
    # Top chamfer cap
    obj.add_box(0, 2.28, 0, 0.30, 0.08, 3.48, u_scale=3.5, v_scale=0.3)
    # Steel lifting rebar loops on top
    obj.add_box(0, 2.38, -1.0, 0.04, 0.12, 0.08)
    obj.add_box(0, 2.38, 1.0, 0.04, 0.12, 0.08)
    obj.write_file(f"{OUTPUT_DIR}/concrete_blast_wall.obj")

# 3. Chainlink Fence (3.0m length, 2.2m height)
def build_chainlink_fence():
    obj = ObjBuilder()
    # Tubular steel support posts (ends and center)
    obj.add_cylinder(-1.5, 1.1, 0, 0.04, 2.2, segments=8)
    obj.add_cylinder(1.5, 1.1, 0, 0.04, 2.2, segments=8)
    # Top and bottom horizontal pipe rails
    obj.add_box(0, 2.15, 0, 3.0, 0.04, 0.04)
    obj.add_box(0, 0.08, 0, 3.0, 0.04, 0.04)
    # Wire mesh double-sided quad (mapped with alpha chainlink)
    uv1 = obj.add_uv(0, 0)
    uv2 = obj.add_uv(6.0, 0)
    uv3 = obj.add_uv(6.0, 4.0)
    uv4 = obj.add_uv(0, 4.0)
    
    v1 = obj.add_vertex(-1.48, 0.1, 0)
    v2 = obj.add_vertex(1.48, 0.1, 0)
    v3 = obj.add_vertex(1.48, 2.12, 0)
    v4 = obj.add_vertex(-1.48, 2.12, 0)
    
    n_fwd = obj.add_normal(0, 0, 1)
    n_bwd = obj.add_normal(0, 0, -1)
    
    obj.add_face([v1, v2, v3, v4], [uv1, uv2, uv3, uv4], [n_fwd]*4)
    obj.add_face([v2, v1, v4, v3], [uv2, uv1, uv4, uv3], [n_bwd]*4)
    
    obj.write_file(f"{OUTPUT_DIR}/chainlink_fence.obj")

# 4. Corrugated Metal Oil Drum (Height 0.9m, Radius 0.3m)
def build_oil_drum():
    obj = ObjBuilder()
    # Main cylinder body
    obj.add_cylinder(0, 0.45, 0, 0.29, 0.9, segments=16)
    # Top and bottom chimes / rims
    obj.add_cylinder(0, 0.03, 0, 0.305, 0.06, segments=16)
    obj.add_cylinder(0, 0.87, 0, 0.305, 0.06, segments=16)
    # Dual rolling ribs / hoops
    obj.add_cylinder(0, 0.32, 0, 0.308, 0.04, segments=16)
    obj.add_cylinder(0, 0.58, 0, 0.308, 0.04, segments=16)
    # Top bung cap
    obj.add_cylinder(0.12, 0.91, 0.06, 0.035, 0.03, segments=8)
    obj.write_file(f"{OUTPUT_DIR}/oil_drum.obj")

# 5. Wooden Cargo Pallet (1.2m x 0.8m x 0.14m)
def build_wooden_pallet():
    obj = ObjBuilder()
    # 3 Longitudinal bottom stringers / skids
    for x in [-0.52, 0.0, 0.52]:
        obj.add_box(x, 0.05, 0, 0.10, 0.08, 0.80)
    # 3 Bottom deck slats
    for z in [-0.34, 0.0, 0.34]:
        obj.add_box(0, 0.01, z, 1.20, 0.02, 0.10)
    # 5 Top deck slats
    for z in [-0.34, -0.17, 0.0, 0.17, 0.34]:
        obj.add_box(0, 0.10, z, 1.20, 0.022, 0.11)
    obj.write_file(f"{OUTPUT_DIR}/wooden_pallet.obj")

# 6. Overturned Armored Vehicle Wreck (Length 5.2m, Width 2.4m, Height 1.8m)
def build_armored_vehicle_wreck():
    obj = ObjBuilder()
    # Vehicle rests tilted on its side at an angle
    # Main armored chassis & hull
    obj.add_box(0, 0.85, 0, 2.2, 1.1, 4.6, u_scale=2.0, v_scale=4.0)
    # Angled glacis plate (sloped front armor)
    obj.add_box(0, 1.1, 2.3, 2.0, 0.6, 0.7)
    # Turret ring & cupola
    obj.add_cylinder(0, 1.55, -0.3, 0.75, 0.35, segments=10)
    # Cannon / autocannon barrel crumpled on ground
    obj.add_cylinder(0.2, 1.55, 1.2, 0.08, 1.8, segments=8)
    # Side armor skirts
    obj.add_box(-1.15, 0.65, 0, 0.15, 0.6, 4.4)
    obj.add_box(1.15, 0.65, 0, 0.15, 0.6, 4.4)
    # Heavy off-road wheels (4 wheels exposed on side and top)
    for z in [-1.5, -0.5, 0.5, 1.5]:
        obj.add_cylinder(1.25, 0.55, z, 0.45, 0.32, segments=10)
        obj.add_cylinder(-1.25, 0.55, z, 0.45, 0.32, segments=10)
        
    obj.write_file(f"{OUTPUT_DIR}/armored_vehicle_wreck.obj")

# 7. 3D Cross-Quad Grass Tuft
def build_grass_tuft():
    obj = ObjBuilder()
    sz = 0.55
    # 3 intersecting vertical quads (angles 0, 60, 120 deg)
    uv1 = obj.add_uv(0, 0)
    uv2 = obj.add_uv(1, 0)
    uv3 = obj.add_uv(1, 1)
    uv4 = obj.add_uv(0, 1)
    
    n_up = obj.add_normal(0, 1, 0)
    
    for angle_deg in [0, 60, 120]:
        a = math.radians(angle_deg)
        dx = math.cos(a) * sz
        dz = math.sin(a) * sz
        
        v1 = obj.add_vertex(-dx, 0, -dz)
        v2 = obj.add_vertex(dx, 0, dz)
        v3 = obj.add_vertex(dx, sz * 1.5, dz)
        v4 = obj.add_vertex(-dx, sz * 1.5, -dz)
        
        obj.add_face([v1, v2, v3, v4], [uv1, uv2, uv3, uv4], [n_up]*4)
        obj.add_face([v2, v1, v4, v3], [uv2, uv1, uv4, uv3], [n_up]*4)
        
    obj.write_file(f"{OUTPUT_DIR}/grass_tuft.obj")

if __name__ == "__main__":
    build_railway_track()
    build_concrete_blast_wall()
    build_chainlink_fence()
    build_oil_drum()
    build_wooden_pallet()
    build_armored_vehicle_wreck()
    build_grass_tuft()
