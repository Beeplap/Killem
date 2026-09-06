# OUTBREAK: Post-Apocalyptic 2.5D Isometric Zombie Shooter (Godot 4)

A gritty, realistic 2.5D isometric survival zombie shooter built natively in **Godot 4.x** with the **GL Compatibility / Mobile** rendering method, heavily inspired by the classic arcade aesthetics of *Zombie Shooter 2* and *Alien Shooter* by Sigma Team.

Pre-configured for cross-platform desktop and mobile deployment (**Windows PC .exe** and **Android .apk**).

---

## 🎮 Gameplay & Visual Architecture

### 1. 2.5D Isometric View & Multi-Directional Sprites
* **Classic 2.5D Slanted Perspective**: Replaced flat bird's-eye circles with multi-directional standing profile sprites. Characters, walls, buildings, and props display realistic vertical height and depth.
* **Y-Sorting Depth**: Real-time Y-sorting (`y_sort_enabled = true`) across the level, entities, walls, and props ensures correct depth ordering as actors walk behind or in front of obstacles.
* **8-Directional Pre-Rendered Characters**:
  * **Soldier**: Full standing profile with combat boots, tactical Kevlar armor, ballistic helmet with night-vision mount, and assault rifle aimed forward in 8 compass directions.
  * **Infected Walker**: Decayed rotting flesh, tattered clothing, blood-stained chest, and lunging posture (6 DMG).
  * **Infected Dog / Hound**: Agile quadruped canine carcass with exposed ribcage and snarling jaws (4 DMG).
  * **Heavy Mutant Brute**: Hulking mutant brute with industrial scrap armor plating and massive fists (14 DMG).
  * **Spitter Mutant**: Acid-mutated zombie with glowing toxic bile pustules (6 DMG).
  * **Armored SWAT Zombie**: Infected military operative with riot helmet and bullet-resistant Kevlar (40% damage resistance).
  * **Colossus Boss**: Enormous behemoth boss with ground-slam fists, volcanic magma fissures, and screen-shaking presence.
* **Tactical Military Crosshair**: Custom precision reticle that dynamically expands and flashes combat red upon firing.
* **Dynamic Wave Progression & Size Scaling**: As waves advance, horde sizes increase progressively, spawn intervals quicken, and zombies grow larger and more menacing!

### 2. High-Detail Realistic Textures (Zero Vector Drawings)
* **Ground**: Gritty seamless dark muddy soil with pebble noise, cracked cold asphalt road, and withered dry dead grass tufts.
* **Railway Corridor**: Granite stone ballast, distressed dark wooden ties with iron plates, and dual oxidized rails with polished specular chrome heads.
* **Structures & Objects**:
  * **Bunker Building**: Industrial concrete bunker ruin with slanted roof, recessed doorway, shattered windows, and an exterior hanging sodium floodlight.
  * **Military Vehicle Wrecks**: Overturned olive-drab pickup and abandoned sedans with rusted body panels and deflated tires.
  * **Reinforced Concrete Walls & Chain-Link Fences**: Modular horizontal and vertical wall blocks with chipped edges and chain-link wire mesh with barbed wire.
* **Destructibles & Props**:
  * **Weathered Wooden Crates**: 3D-shaded isometric crates with diagonal wooden braces and iron corner rivets.
  * **Heavy Polyethylene Trash Bags**: Wrinkled black garbage sacks with glossy reflections.
  * **Explosive Chemical Barrels**: Rusted industrial drums with biohazard markings.
* **Decals**: Visceral coagulated crimson blood splat decals randomly generated on enemy deaths.

### 3. Realistic 2D Lighting, Shadows & Particle Effects
* **Overcast Slate Daylight (`#b0b5bd`)**: The level features visible overcast daylight illumination, ensuring ground, tracks, walls, and zombie silhouettes are visible across the screen at all times.
* **Tactical Weapon Flashlight**: PointLight2D cone with a realistic volumetric light cookie attached to the player's weapon aim vector, casting dynamic realtime soft shadows via `LightOccluder2D` on walls, fences, vehicles, and crates.
* **Atmospheric Bunker Sodium Lamp**: Flickering overhead industrial lamp casting warm amber light over the bunker entrance with dynamic shadows.
* **Impact & Explosion Particles**:
  * **Bullet Impacts**: Dynamic sparks flying along the ricochet normal, concrete/metal dust, blood spray on enemy hits, and lingering smoke puffs.
  * **Barrel Detonations**: Blinding light flash, burst of fiery embers, and billowing heavy black smoke.

---

## 📁 Project Structure

```
game/
├── project.godot                # Godot 4.x project settings (GL Compatibility, 1280x720 canvas_items)
├── export_presets.cfg           # Pre-configured Windows Desktop (.exe) & Android (.apk) presets
├── icon.svg                     # Vector biohazard crosshair project icon
├── assets/
│   └── textures/
│       ├── ground/              # dirt_terrain.png, cracked_asphalt.png, dead_grass.png
│       ├── railway/             # railway_track.png, hazard_platform.png
│       ├── environment/         # bunker_building.png, military_truck_wreck.png, concrete_wall_h/v.png, chainlink_fence_h.png
│       ├── props/               # crate_isometric.png, trash_bag.png, oil_barrel.png, pickup_health/ammo.png, bullet_tracer.png
│       ├── decals/              # blood_splat_1.png, blood_splat_2.png, blood_splat_3.png
│       ├── lighting/            # flashlight_cookie.png, point_light_cookie.png
│       └── characters/          # soldier_8dir.png, zombie_regular_8dir.png, zombie_dog_8dir.png, zombie_heavy_8dir.png
├── scenes/
│   ├── MainLevel.tscn           # 2.5D Isometric map with dynamic lighting, shadows, walls, props
│   ├── Player.tscn              # 2.5D Soldier CharacterBody2D with Camera2D, Flashlight, Muzzle
│   ├── Zombie.tscn              # 2.5D Walker zombie with NavigationAgent2D
│   ├── InfectedDog.tscn         # 2.5D Infected dog
│   ├── HeavyZombie.tscn         # 2.5D Heavy mutant brute
│   ├── Bullet.tscn              # Area2D bullet projectile with tracer sprite
│   ├── DestructibleCrate.tscn   # Weathered wooden crate with LightOccluder2D
│   ├── TrashBag.tscn            # Destructible trash bag
│   ├── OilBarrel.tscn           # Explosive barrel with LightOccluder2D
│   ├── Pickup.tscn              # Medkit and ammo pickups
│   └── HUD.tscn                 # Retro arcade CanvasLayer interface
├── scripts/
│   ├── global.gd                # Autoload singleton managing score, wave, audio, and weapon state
│   ├── player.gd                # 8-directional movement, aiming, scroll zoom, flashlight, and shooting
│   ├── zombie.gd                # 8-directional NavigationAgent2D AI, variant behaviors, loot drops
│   ├── bullet.gd                # High-speed projectile with impact spark/smoke particles
│   ├── bullet_pool.gd           # Node pool managing pre-allocated projectiles
│   ├── destructible_prop.gd     # Damage, fire/smoke explosion effects, and debris particles
│   ├── blood_splat.gd           # High-resolution persistent blood decal placement
│   ├── pickup.gd                # Auto-collectible health and ammo items
│   ├── spawner.gd               # Wave progression and horde perimeter spawner
│   ├── main_level.gd            # Atmospheric sodium light flicker and 2.5D depth setup
│   └── hud.gd                   # HUD signals, health bar, and game-over overlay
└── tools/
    └── generate_all_assets.py   # Procedural realistic texture and sprite sheet generator
```

---

## 🕹️ Controls

| Action | PC Controls | Mobile / Touch |
| :--- | :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` or Arrow Keys | Left Screen Drag / Touch |
| **Aim** | Mouse Cursor | Touch Direction |
| **Fire** | Left Mouse Button | Right Screen Tap / Fire |
| **Camera Zoom** | Mouse Scroll Wheel (Up/Down) | Pinch Gesture |
| **Pistol (9MM)** | Key `[1]` | On-screen `[1] 9MM` button |
| **Shotgun (12G)** | Key `[2]` | On-screen `[2] SHG` button |
| **Assault Rifle** | Key `[3]` | On-screen `[3] RIFLE` button |
| **Restart (Game Over)**| Key `[R]` | Tap Screen |

---

## 🚀 Running & Exporting

### Running in Godot 4
1. Open Godot 4.x.
2. Select the `project.godot` file in this directory.
3. Click **Run Project** (`F5`) to play `scenes/MainLevel.tscn`.

### Exporting
* **Windows Desktop**: Project -> Export -> Select `Windows Desktop` -> Export Project (`Builds/Windows/Outbreak.exe`).
* **Android**: Project -> Export -> Select `Android` -> Export Project (`Builds/Android/Outbreak.apk`).
