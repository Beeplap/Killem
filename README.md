# KillEm: Post-Apocalyptic Isometric Zombie Shooter (Godot 4)

A gritty, tactical isometric survival zombie shooter built natively in **Godot 4.x** with the **GL Compatibility / Mobile** rendering method, heavily inspired by the arcade aesthetics of *Zombie Shooter 2* and *Alien Shooter* by Sigma Team.

Pre-configured for cross-platform desktop and mobile deployment (**Windows PC .exe** and **Android .apk**).

---

## 🎮 Gameplay & Visual Architecture

### 1. Dual Mode Engine: Classic 2.5D & Next-Gen True 3D
* **True 3D Terrain3D Integration (`scenes/levels/BaseLevel3D.tscn`)**:
  * Utilizes high-performance GDExtension `Terrain3D` with multi-texture PBR materials:
    * **Slot 0:** Dark Muddy Wasteland Dirt (`dirt_terrain.png` + normal map)
    * **Slot 1:** Cracked Weathered Asphalt with gravel undertones (`cracked_asphalt.png` + normal map)
    * **Slot 2:** Dead Dry Scrubland Grass (`scrub_grass_512.png` + normal map)
  * Continuous procedural heightmap with a flat central tactical clearing (36m radius) blended into undulating perimeter trenches.
  * Zero draw-call GPU foliage and debris instancing (dead grass clumps, small rocks, weathered debris pallets).
  * Runtime 3D navigation mesh baking via `NavigationServer3D` parsing 39,000+ terrain faces and static obstacle geometry.
  * Dual-layer height clamping on player and zombie physics bodies to prevent surface clipping.
* **Classic 2.5D Isometric Mode (`scenes/MainLevel.tscn`)**:
  * Multi-directional standing profile sprites with real-time Y-sorting (`y_sort_enabled = true`).
  * Tactical flashlight casting soft shadows via `LightOccluder2D` and atmospheric sodium vapor floodlights.
  * Persistent blood decals, bullet tracers, and particle sparks.

### 2. Tiered Zombie AI Hierarchy
* **Shambler / Infected Walker**: Decayed decaying flesh, lunging posture, swarm behavior (6 DMG).
* **Plague Hound**: Agile quadruped canine runner that sprints and flanks the player (4 DMG).
* **Toxic Spitter**: Long-range mutant that launches acidic bile globes (6 DMG).
* **Super Mutant Brute**: Hulking bullet sponge with reinforced scrap armor and ground-pound knockback (14 DMG).
* **Armored SWAT Zombie**: Infected military operative with riot helmet and bullet-resistant Kevlar (40% damage resistance).
* **Colossus Boss**: Enormous behemoth boss with ground-slam fissures and screen-shaking presence.

### 3. Procedural 3D Weapon Models & Socket Rigging
* Custom procedural PBR weapon meshes created directly in Godot 4:
  * **9mm Combat Pistol**: Matte gunmetal steel slide, tactical polymer frame, tritium night-sights.
  * **Pump-Action Shotgun**: Heat shield barrel, textured slide pump, brass 12-gauge shells.
  * **Tactical AK-47**: Weathered dark composite stock, ribbed steel receiver, curved magazine, zero screen-shake profile.
  * **Flamethrower & Minigun**: High-output heavy suppression weapons.
* Mechanical animated slides, recoil kickback, brass shell ejector particles, and hand socket rigging (`RightHandSocket`).

### 4. Tactical Cover & Choke Points
* **Waist-High Cover Points**: Modular `SandbagBarricade.tscn` positions, concrete blast walls, and wooden pallets providing strategic firing bunkers.
* **Funneling Choke Points**: Derailed `IndustrialContainer.tscn` shipping containers and chainlink fences creating narrow kill zones and ambush corridors.
* **Explosive Chain Cascades**: Rusted biohazard `OilDrum.tscn` barrels with delayed chain-reaction detonations.

### 5. Multi-Bus Tactical Audio Architecture
* Mastering pipeline configured in `default_bus_layout.tres`:
  * **Master Bus**: `AudioEffectLimiter` (Ceiling: `-0.5 dB`, Threshold: `-2.0 dB`) to prevent combat distortion.
  * **Weapons Bus**: Fast-attack compression ducking SFX bus by `-2.5 dB` during rapid firing.
  * **Zombies Bus**: Atmospheric industrial reverb (wet `0.12`, room `0.2`).
  * **Foley & Footsteps**: Subtle, non-intrusive footstep audio modulated by surface material (dirt, asphalt, metal).
  * **Pickups & UI**: Crisp interaction chimes.

### 6. Campaign & Objective System (`scripts/mission_manager.gd`)
* Dynamic objective tracker with state progression:
  * **Find Keycard**: Search the railway yard depot to locate the Yellow Security Keycard.
  * **Override Blast Door**: Insert keycard into blast gate terminal to unlock the northern perimeter.
  * **Defend Generator**: Insert fuel cell and hold out during a 45-second siege horde attack.
  * **Survivor Data Extraction**: Hack military terminal and repel room breaches.

---

## 📁 Project Structure

```
game/
├── project.godot                # Godot 4.x project settings (KillEm, 1280x720)
├── export_presets.cfg           # Windows Desktop (KillEm.exe) & Android (KillEm.apk)
├── default_bus_layout.tres      # Multi-bus audio mastering layout
├── icon.svg                     # Biohazard tactical crosshair icon
├── addons/
│   └── terrain_3d/              # Terrain3D GDExtension plugin & shaders
├── data/
│   └── terrain/                 # terrain_assets.tres, terrain_material.tres
├── assets/
│   ├── textures/
│   │   ├── ground/              # dirt_terrain, cracked_asphalt, scrub_grass_512
│   │   ├── props/               # metal_barrel, crates, pallets
│   │   └── decals/              # blood_splat, oil_slick, blast_scorch
│   └── audio/                   # 16-bit 44.1kHz tactical sound library
├── scenes/
│   ├── levels/
│   │   └── BaseLevel3D.tscn     # True 3D Terrain3D Level with cover, choke points & navmesh
│   ├── MainLevel.tscn           # Classic 2.5D Isometric Survival Level
│   ├── entities/
│   │   └── Player3D.tscn        # 3D Player with socket rigging & procedural weapons
│   ├── enemies/
│   │   ├── ShamblerZombie3D.tscn
│   │   ├── PlagueHound3D.tscn
│   │   ├── ToxicSpitter3D.tscn
│   │   └── SuperMutant3D.tscn
│   ├── environment/             # SandbagBarricade, IndustrialContainer, ConcreteBlastWall, etc.
│   ├── interactables/           # KeycardPickup3D, BlastDoor3D, GeneratorDefense3D, DataTerminal3D
│   └── ui/
│       ├── MainMenu.tscn        # Tactical landing page with mode selector & settings
│       ├── SettingsMenu.tscn    # Graphics, audio bus sliders & control remap
│       └── MobileControls.tscn  # Responsive virtual twin-stick controls
├── scripts/
│   ├── global.gd                # Global game state, scoring, signals, weapon cache
│   ├── audio_manager.gd         # Spatial 3D/2D audio pool manager
│   ├── base_level_3d.gd         # 3D terrain setup, navmesh baking & mission bootstrap
│   ├── player_3d.gd             # 3D kinematic movement, aiming, weapon handling & terrain snapping
│   ├── base_zombie_3d.gd        # NavigationAgent3D zombie AI with terrain height snapping
│   └── mission_manager.gd       # Dynamic campaign objective tracking
└── tools/
    ├── build_authentic_tactical_audio.py # Audio synthesis pipeline
    └── generate_all_assets.py   # Procedural texture generator
```

---

## 🕹️ Controls

| Action | PC Controls | Mobile / Touch |
| :--- | :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` or Arrow Keys | Left Virtual Joystick |
| **Aim** | Mouse Cursor / 3D Raycast Plane | Right Virtual Aim Joystick |
| **Fire** | Left Mouse Button | Auto-fire / Right Trigger Button |
| **Dodge Dash** | `Space` | On-screen Dodge Button |
| **Reload** | `R` | On-screen Reload Button |
| **Interact / Objective**| `E` | Contextual Interact Button |
| **Pistol (9MM)** | Key `[1]` | On-screen `[1]` Weapon Tab |
| **Shotgun (12G)** | Key `[2]` | On-screen `[2]` Weapon Tab |
| **Assault Rifle (AK)**| Key `[3]` | On-screen `[3]` Weapon Tab |
| **Flamethrower** | Key `[4]` | On-screen `[4]` Weapon Tab |
| **Minigun** | Key `[5]` | On-screen `[5]` Weapon Tab |
| **Settings / Pause** | `Esc` | Top-right Cog Icon |

---

## 🚀 Running & Exporting

### Running in Godot 4
1. Open Godot 4.x (v4.3+ or v4.7+ compatible).
2. Select the `project.godot` file in this directory.
3. Click **Run Project** (`F5`) to launch the `MainMenu.tscn` landing page.
4. Choose **Survive (2.5D)** or **3D Campaign** to enter combat.

### Exporting
* **Windows Desktop**: Project -> Export -> Select `Windows Desktop` -> Export Project (`Builds/Windows/KillEm.exe`).
* **Android Mobile**: Project -> Export -> Select `Android` -> Export Project (`Builds/Android/KillEm.apk`).

