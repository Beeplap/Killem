import os

scenes = {}

scenes["scenes/environment/ConcreteBlastWall.tscn"] = """[gd_scene load_steps=5 format=3]

[ext_resource type="ArrayMesh" path="res://assets/models/environment/concrete_blast_wall.obj" id="1_mesh"]
[ext_resource type="Texture2D" path="res://assets/textures/environment/concrete_wall_pbr.png" id="2_tex"]
[ext_resource type="Texture2D" path="res://assets/textures/environment/concrete_wall_pbr_n.png" id="3_norm"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wall"]
albedo_texture = ExtResource("2_tex")
normal_enabled = true
normal_texture = ExtResource("3_norm")
roughness = 0.85
uv1_scale = Vector3(1, 1, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_wall"]
size = Vector3(0.9, 2.3, 3.5)

[node name="ConcreteBlastWall" type="StaticBody3D" groups=["obstacles"]]
collision_layer = 4
collision_mask = 7

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_wall")
mesh = ExtResource("1_mesh")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.15, 0)
shape = SubResource("BoxShape3D_wall")
"""

scenes["scenes/environment/RailwayTrack.tscn"] = """[gd_scene load_steps=5 format=3]

[ext_resource type="ArrayMesh" path="res://assets/models/environment/railway_track.obj" id="1_mesh"]
[ext_resource type="Texture2D" path="res://assets/textures/railway/railway_track.png" id="2_tex"]
[ext_resource type="Texture2D" path="res://assets/textures/railway/railway_track_n.png" id="3_norm"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_rail"]
albedo_texture = ExtResource("2_tex")
normal_enabled = true
normal_texture = ExtResource("3_norm")
roughness = 0.65
metallic = 0.5

[sub_resource type="BoxShape3D" id="BoxShape3D_rail"]
size = Vector3(2.4, 0.4, 6.0)

[node name="RailwayTrack" type="StaticBody3D"]
collision_layer = 4
collision_mask = 7

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_rail")
mesh = ExtResource("1_mesh")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.2, 0)
shape = SubResource("BoxShape3D_rail")
"""

scenes["scenes/environment/ChainlinkFence.tscn"] = """[gd_scene load_steps=4 format=3]

[ext_resource type="ArrayMesh" path="res://assets/models/environment/chainlink_fence.obj" id="1_mesh"]
[ext_resource type="Texture2D" path="res://assets/textures/environment/chainlink_wire.png" id="2_tex"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wire"]
transparency = 2
alpha_scissor_threshold = 0.5
cull_mode = 0
albedo_texture = ExtResource("2_tex")
roughness = 0.5
metallic = 0.8
uv1_scale = Vector3(3, 2, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_fence"]
size = Vector3(0.3, 2.5, 3.2)

[node name="ChainlinkFence" type="StaticBody3D" groups=["obstacles"]]
collision_layer = 4
collision_mask = 7

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_wire")
mesh = ExtResource("1_mesh")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.25, 0)
shape = SubResource("BoxShape3D_fence")
"""

scenes["scenes/environment/OilDrum.tscn"] = """[gd_scene load_steps=5 format=3]

[ext_resource type="ArrayMesh" path="res://assets/models/environment/oil_drum.obj" id="1_mesh"]
[ext_resource type="Texture2D" path="res://assets/textures/props/metal_barrel_pbr.png" id="2_tex"]
[ext_resource type="Texture2D" path="res://assets/textures/props/metal_barrel_pbr_n.png" id="3_norm"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_drum"]
albedo_texture = ExtResource("2_tex")
normal_enabled = true
normal_texture = ExtResource("3_norm")
roughness = 0.55
metallic = 0.75

[sub_resource type="CylinderShape3D" id="CylinderShape3D_drum"]
height = 1.1
radius = 0.38

[node name="OilDrum" type="StaticBody3D" groups=["obstacles", "destructibles"]]
collision_layer = 4
collision_mask = 7

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_drum")
mesh = ExtResource("1_mesh")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.55, 0)
shape = SubResource("CylinderShape3D_drum")
"""

scenes["scenes/environment/WoodenPallet.tscn"] = """[gd_scene load_steps=5 format=3]

[ext_resource type="ArrayMesh" path="res://assets/models/environment/wooden_pallet.obj" id="1_mesh"]
[ext_resource type="Texture2D" path="res://assets/textures/props/wooden_pallet_pbr.png" id="2_tex"]
[ext_resource type="Texture2D" path="res://assets/textures/props/wooden_pallet_pbr_n.png" id="3_norm"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_pallet"]
albedo_texture = ExtResource("2_tex")
normal_enabled = true
normal_texture = ExtResource("3_norm")
roughness = 0.88

[sub_resource type="BoxShape3D" id="BoxShape3D_pallet"]
size = Vector3(1.2, 0.22, 1.0)

[node name="WoodenPallet" type="StaticBody3D" groups=["obstacles"]]
collision_layer = 4
collision_mask = 7

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_pallet")
mesh = ExtResource("1_mesh")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.11, 0)
shape = SubResource("BoxShape3D_pallet")
"""

scenes["scenes/environment/OverturnedVehicle.tscn"] = """[gd_scene load_steps=5 format=3]

[ext_resource type="ArrayMesh" path="res://assets/models/environment/armored_vehicle_wreck.obj" id="1_mesh"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wreck"]
albedo_color = Color(0.22, 0.24, 0.22, 1)
metallic = 0.7
roughness = 0.65

[sub_resource type="BoxShape3D" id="BoxShape3D_wreck"]
size = Vector3(2.6, 2.0, 5.2)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_smoke"]
shading_mode = 0
albedo_color = Color(0.2, 0.2, 0.2, 0.6)

[sub_resource type="SphereMesh" id="SphereMesh_smoke"]
material = SubResource("StandardMaterial3D_smoke")
radius = 0.25
height = 0.5

[node name="OverturnedVehicle" type="StaticBody3D" groups=["obstacles"]]
collision_layer = 4
collision_mask = 7

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_wreck")
mesh = ExtResource("1_mesh")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.0, 0)
shape = SubResource("BoxShape3D_wreck")

[node name="SmokeParticles" type="CPUParticles3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.3, 1.2, 0.5)
amount = 20
lifetime = 1.8
speed_scale = 0.8
mesh = SubResource("SphereMesh_smoke")
emission_shape = 1
emission_sphere_radius = 0.3
direction = Vector3(0, 1, 0)
spread = 25.0
initial_velocity_min = 0.6
initial_velocity_max = 1.4
gravity = Vector3(0.2, 0.4, 0)
scale_amount_min = 0.6
scale_amount_max = 2.2
"""

scenes["scenes/environment/GrassTuft.tscn"] = """[gd_scene load_steps=4 format=3]

[ext_resource type="ArrayMesh" path="res://assets/models/environment/grass_tuft.obj" id="1_mesh"]
[ext_resource type="Texture2D" path="res://assets/textures/environment/grass_tuft.png" id="2_tex"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_grass"]
transparency = 2
alpha_scissor_threshold = 0.4
cull_mode = 0
albedo_texture = ExtResource("2_tex")
roughness = 0.9

[node name="GrassTuft" type="Node3D"]

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_grass")
mesh = ExtResource("1_mesh")
"""

with open("scenes/entities/Player3D.tscn", "r", encoding="utf-8") as f:
    player_content = f.read()

scenes["scenes/player/Player3D.tscn"] = player_content

scenes["scenes/levels/BaseLevel3D.tscn"] = """[gd_scene load_steps=22 format=3]

[ext_resource type="Script" path="res://scripts/base_level_3d.gd" id="1_level"]
[ext_resource type="Script" path="res://scripts/camera_isometric_3d.gd" id="2_camera"]
[ext_resource type="PackedScene" path="res://scenes/entities/Player3D.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/environment/ConcreteBlastWall.tscn" id="4_wall"]
[ext_resource type="PackedScene" path="res://scenes/environment/RailwayTrack.tscn" id="5_rail"]
[ext_resource type="PackedScene" path="res://scenes/environment/ChainlinkFence.tscn" id="6_fence"]
[ext_resource type="PackedScene" path="res://scenes/environment/OilDrum.tscn" id="7_drum"]
[ext_resource type="PackedScene" path="res://scenes/environment/WoodenPallet.tscn" id="8_pallet"]
[ext_resource type="PackedScene" path="res://scenes/environment/OverturnedVehicle.tscn" id="9_wreck"]
[ext_resource type="PackedScene" path="res://scenes/environment/GrassTuft.tscn" id="10_grass"]
[ext_resource type="Texture2D" path="res://assets/textures/ground/dirt_terrain.png" id="11_dirt"]
[ext_resource type="Texture2D" path="res://assets/textures/ground/dirt_terrain_n.png" id="12_dirt_n"]
[ext_resource type="Texture2D" path="res://assets/textures/ground/asphalt_road_pbr.png" id="13_asphalt"]
[ext_resource type="Texture2D" path="res://assets/textures/ground/asphalt_road_pbr_n.png" id="14_asphalt_n"]
[ext_resource type="Texture2D" path="res://assets/textures/decals/oil_slick.png" id="15_slick"]
[ext_resource type="Texture2D" path="res://assets/textures/decals/blast_scorch.png" id="16_scorch"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_sky"]
sky_top_color = Color(0.35, 0.4, 0.48, 1)
sky_horizon_color = Color(0.68, 0.72, 0.78, 1)
ground_bottom_color = Color(0.2, 0.22, 0.25, 1)
ground_horizon_color = Color(0.68, 0.72, 0.78, 1)

[sub_resource type="Sky" id="Sky_sky"]
sky_material = SubResource("ProceduralSkyMaterial_sky")

[sub_resource type="Environment" id="Environment_env"]
background_mode = 2
sky = SubResource("Sky_sky")
ambient_light_source = 2
ambient_light_color = Color(0.88, 0.9, 0.94, 1)
ambient_light_sky_contribution = 0.55
tonemap_mode = 3
ssao_enabled = true
ssao_radius = 1.4
ssao_intensity = 2.2
ssao_power = 1.5
volumetric_fog_enabled = true
volumetric_fog_density = 0.02
volumetric_fog_albedo = Color(0.75, 0.78, 0.84, 1)
volumetric_fog_ambient_inject = 0.3

[sub_resource type="NavigationMesh" id="NavigationMesh_nav"]
geometry_parsed_geometry_type = 1
agent_radius = 0.45
agent_height = 1.8
agent_max_climb = 0.35
agent_max_slope = 45.0

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_dirt"]
albedo_texture = ExtResource("11_dirt")
normal_enabled = true
normal_texture = ExtResource("12_dirt_n")
roughness = 0.9
uv1_scale = Vector3(12, 12, 12)

[sub_resource type="PlaneMesh" id="PlaneMesh_ground"]
material = SubResource("StandardMaterial3D_dirt")
size = Vector2(70, 70)

[sub_resource type="BoxShape3D" id="BoxShape3D_ground"]
size = Vector3(70, 0.2, 70)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_road"]
albedo_texture = ExtResource("13_asphalt")
normal_enabled = true
normal_texture = ExtResource("14_asphalt_n")
roughness = 0.82
uv1_scale = Vector3(1, 6, 1)

[sub_resource type="PlaneMesh" id="PlaneMesh_road"]
material = SubResource("StandardMaterial3D_road")
size = Vector2(10, 60)

[sub_resource type="BoxShape3D" id="BoxShape3D_road"]
size = Vector3(10, 0.2, 60)

[node name="BaseLevel3D" type="Node3D"]
script = ExtResource("1_level")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_env")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.819152, -0.32899, 0.469846, 0, 0.819152, 0.573576, -0.573576, -0.469846, 0.67101, 0, 20, 0)
light_color = Color(0.96, 0.98, 1, 1)
light_energy = 1.25
light_volumetric_fog_energy = 1.5
shadow_enabled = true
directional_shadow_mode = 1
directional_shadow_bias_split_scale = 0.1

[node name="IsometricCamera" type="Camera3D" parent="."]
transform = Transform3D(0.707107, -0.579228, 0.40558, 0, 0.573576, 0.819152, -0.707107, -0.579228, 0.40558, 13.76, 19.66, 13.76)
rotation_degrees = Vector3(-55, 45, 0)
fov = 35.0
size = 16.0
current = true
script = ExtResource("2_camera")
target_path = NodePath("../Player3D")
distance = 24.0

[node name="Player3D" parent="." instance=ExtResource("3_player")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, 0)

[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("NavigationMesh_nav")

[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]
collision_layer = 4
collision_mask = 7

[node name="DirtMesh" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]
mesh = SubResource("PlaneMesh_ground")

[node name="DirtCollision" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)
shape = SubResource("BoxShape3D_ground")

[node name="AsphaltRoad" type="StaticBody3D" parent="NavigationRegion3D"]
transform = Transform3D(0.92388, 0, 0.382683, 0, 1, 0, -0.382683, 0, 0.92388, -2, 0.02, 0)
collision_layer = 4
collision_mask = 7

[node name="RoadMesh" type="MeshInstance3D" parent="NavigationRegion3D/AsphaltRoad"]
mesh = SubResource("PlaneMesh_road")

[node name="RoadCollision" type="CollisionShape3D" parent="NavigationRegion3D/AsphaltRoad"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)
shape = SubResource("BoxShape3D_road")

[node name="Railway" type="Node3D" parent="NavigationRegion3D"]
transform = Transform3D(0.707107, 0, -0.707107, 0, 1, 0, 0.707107, 0, 0.707107, 8, 0, -8)

[node name="TrackSegment1" parent="NavigationRegion3D/Railway" instance=ExtResource("5_rail")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -18)

[node name="TrackSegment2" parent="NavigationRegion3D/Railway" instance=ExtResource("5_rail")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -12)

[node name="TrackSegment3" parent="NavigationRegion3D/Railway" instance=ExtResource("5_rail")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -6)

[node name="TrackSegment4" parent="NavigationRegion3D/Railway" instance=ExtResource("5_rail")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)

[node name="TrackSegment5" parent="NavigationRegion3D/Railway" instance=ExtResource("5_rail")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 6)

[node name="TrackSegment6" parent="NavigationRegion3D/Railway" instance=ExtResource("5_rail")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 12)

[node name="TrackSegment7" parent="NavigationRegion3D/Railway" instance=ExtResource("5_rail")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 18)

[node name="BlastWallNorth1" parent="NavigationRegion3D" instance=ExtResource("4_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -8, 0, -14)

[node name="BlastWallNorth2" parent="NavigationRegion3D" instance=ExtResource("4_wall")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.6, 0, -14)

[node name="BlastWallNorth3" parent="NavigationRegion3D" instance=ExtResource("4_wall")]
transform = Transform3D(0.965926, 0, 0.258819, 0, 1, 0, -0.258819, 0, 0.965926, 12, 0, -16)

[node name="BlastWallNorth4" parent="NavigationRegion3D" instance=ExtResource("4_wall")]
transform = Transform3D(0.965926, 0, 0.258819, 0, 1, 0, -0.258819, 0, 0.965926, 15.3, 0, -15.1)

[node name="FenceWest1" parent="NavigationRegion3D" instance=ExtResource("6_fence")]
transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -18, 0, -8)

[node name="FenceWest2" parent="NavigationRegion3D" instance=ExtResource("6_fence")]
transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -18, 0, -4.8)

[node name="FenceWest3" parent="NavigationRegion3D" instance=ExtResource("6_fence")]
transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -18, 0, -1.6)

[node name="FenceWest4" parent="NavigationRegion3D" instance=ExtResource("6_fence")]
transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -18, 0, 1.6)

[node name="OilDrum1" parent="NavigationRegion3D" instance=ExtResource("7_drum")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5.5, 0, 4.2)

[node name="OilDrum2" parent="NavigationRegion3D" instance=ExtResource("7_drum")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -4.8, 0, 4.8)

[node name="OilDrum3" parent="NavigationRegion3D" instance=ExtResource("7_drum")]
transform = Transform3D(0.965926, 0, 0.258819, 0, 1, 0, -0.258819, 0, 0.965926, -5.2, 0, 5.5)

[node name="Pallet1" parent="NavigationRegion3D" instance=ExtResource("8_pallet")]
transform = Transform3D(0.965926, 0, 0.258819, 0, 1, 0, -0.258819, 0, 0.965926, 6, 0, 3)

[node name="Pallet2" parent="NavigationRegion3D" instance=ExtResource("8_pallet")]
transform = Transform3D(0.707107, 0, 0.707107, 0, 1, 0, -0.707107, 0, 0.707107, 6.2, 0.22, 3.1)

[node name="VehicleWreck" parent="NavigationRegion3D" instance=ExtResource("9_wreck")]
transform = Transform3D(0.866025, 0.173648, 0.469846, -0.2, 0.979796, 0.007, -0.459, -0.1, 0.882, -10, 0, 10)

[node name="GrassTuft1" parent="NavigationRegion3D" instance=ExtResource("10_grass")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, -6)

[node name="GrassTuft2" parent="NavigationRegion3D" instance=ExtResource("10_grass")]
transform = Transform3D(1.2, 0, 0, 0, 1.2, 0, 0, 0, 1.2, 4, 0, 8)

[node name="GrassTuft3" parent="NavigationRegion3D" instance=ExtResource("10_grass")]
transform = Transform3D(0.8, 0, 0, 0, 0.8, 0, 0, 0, 0.8, -12, 0, 2)

[node name="Decals" type="Node3D" parent="."]

[node name="OilSlickDecal1" type="Decal" parent="Decals"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5.2, 0.1, 4.8)
size = Vector3(3.2, 1.0, 3.2)
texture_albedo = ExtResource("15_slick")

[node name="OilSlickDecal2" type="Decal" parent="Decals"]
transform = Transform3D(0.707107, 0, 0.707107, 0, 1, 0, -0.707107, 0, 0.707107, -9.5, 0.1, 9.2)
size = Vector3(4.5, 1.0, 4.0)
texture_albedo = ExtResource("15_slick")

[node name="ScorchDecal1" type="Decal" parent="Decals"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0.1, -4)
size = Vector3(4.0, 1.0, 4.0)
texture_albedo = ExtResource("16_scorch")

[node name="ScorchDecal2" type="Decal" parent="Decals"]
transform = Transform3D(0.866025, 0, 0.5, 0, 1, 0, -0.5, 0, 0.866025, -7, 0.1, 14)
size = Vector3(3.5, 1.0, 3.5)
texture_albedo = ExtResource("16_scorch")
"""

for path, content in scenes.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Successfully built:", path)
