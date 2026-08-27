# OUTBREAK: Post-Apocalyptic Top-Down Zombie Shooter (Godot 4)

A top-down arcade survival zombie shooter built natively in **Godot 4.x** with the **GL Compatibility / Mobile** rendering method, inspired by classic 2000s top-down arcade games like *Zombie Shooter* and *Alien Shooter* by Sigma Team.

Pre-configured for cross-platform desktop and mobile deployment (**Windows PC .exe** and **Android .apk**).

---

## 🎮 Gameplay & Core Features

### 1. Player & Combat Mechanics
* **CharacterBody2D Movement**: WASD / Arrow key movement with smooth acceleration, deceleration, and physics sliding.
* **360° Mouse Aiming**: The player character rotates smoothly to face the mouse cursor or touch target.
* **Mouse-Wheel Camera Zoom**: Dedicated camera zoom mapped strictly to `MOUSE_BUTTON_WHEEL_UP` and `MOUSE_BUTTON_WHEEL_DOWN`. Weapon switching is strictly isolated to number keys `[1]`, `[2]`, and `[3]`.
* **Shooting & Node Pooling**: High-performance `BulletPool` node pooling system pre-allocating luminous tracer projectiles (`Area2D`) with zero runtime garbage collection pauses.
* **Arsenal**:
  * `[1] 9MM PISTOL`: Reliable sidearm with unlimited ammunition.
  * `[2] 12G SHOTGUN`: Heavy 6-pellet conical buckshot blast with camera recoil shake.
  * `[3] ASSAULT RIFLE`: High-cadence automatic rifle fire.

### 2. Infected AI (`NavigationAgent2D`)
* **Regular Walker**: Relentless shambling infected civilian (80 HP, 130 px/s).
* **Fast Infected Dog**: Low-profile quadruped predator with high sprint speed (45 HP, 240 px/s) that rushes the player.
* **Heavy Mutant Brute**: Bloated tank with reinforced plating and high knockback resistance (260 HP, 75 px/s).
* **Intelligent Pathfinding**: Powered by `NavigationAgent2D` traversing walkable zones around obstacles, walls, and props with fallback direct tracking.
* **Permanent Blood Decals**: Defeated enemies leave organic blood splats that persist on the ground tiles.

### 3. Open-World Post-Apocalyptic Level
* **Well-Lit Open Terrain**: Daytime/sodium ambient lighting (no pitch-black fog-of-war) over dirt ground and diagonal dark asphalt roadways.
* **Broken Railway System**: Dual steel rails, wooden railroad ties, gravel ballast bed, and caution hazard platforms.
* **Destructible Props**:
  * **Wooden Crates**: 35 HP, breaks into wooden shrapnel particles.
  * **Trash Bags**: 20 HP, squishes and bursts into debris particles.
  * **Explosive Barrels**: 25 HP, detonates causing area-of-effect damage to nearby zombies and player, with chain-reaction capabilities.
* **Loot Drop Table**:
  * 40% Health Pack (+35 HP)
  * 40% Ammo Crate (Shotgun shells + Rifle rounds)
  * 20% Empty

### 4. Retro Arcade HUD
* **Vitals Gauge**: Blood-red metallic health bar anchored to the bottom-left with HP readout.
* **Weapon & Ammo Display**: Stark yellow/white retro arcade terminal anchored to the bottom-right showing active weapon name and current ammunition reserves.
* **Score & Wave Tracker**: Score, kill counter, and wave banner.
* **Mobile Touch Controls**: On-screen weapon selection buttons and touch support for Android devices.

---

## 📁 Project Structure

```
game/
├── project.godot                # Godot 4.x project settings (GL Compatibility, 1280x720 canvas_items)
├── export_presets.cfg           # Pre-configured Windows Desktop (.exe) & Android (.apk) presets
├── icon.svg                     # Vector biohazard crosshair project icon
├── scenes/
│   ├── MainLevel.tscn           # Open-world map with NavigationRegion2D, props, spawner, player
│   ├── Player.tscn              # Player CharacterBody2D with Camera2D & Muzzle
│   ├── Zombie.tscn              # Regular walker zombie with NavigationAgent2D
│   ├── InfectedDog.tscn         # Fast quadruped infected canine
│   ├── HeavyZombie.tscn         # Heavy mutant brute
│   ├── Bullet.tscn              # Area2D bullet projectile
│   ├── DestructibleCrate.tscn   # Wooden crate prop
│   ├── TrashBag.tscn            # Destructible trash bag prop
│   ├── OilBarrel.tscn           # Explosive oil barrel prop
│   ├── Pickup.tscn              # Health and Ammo pick-up items
│   └── HUD.tscn                 # Retro arcade CanvasLayer interface
└── scripts/
    ├── global.gd                # Autoload singleton managing score, wave, audio, and weapon state
    ├── player.gd                # Movement, mouse aiming, scroll zoom, and shooting logic
    ├── zombie.gd                # NavigationAgent2D AI, variant behaviors, and loot drops
    ├── bullet.gd                # Tracer projectile movement and collision logic
    ├── bullet_pool.gd           # Node pool managing pre-allocated projectiles
    ├── destructible_prop.gd     # Damage, explosive barrels, and debris burst particles
    ├── blood_splat.gd           # Procedural persistent floor blood splatters
    ├── pickup.gd                # Auto-collectible health and ammo items
    ├── spawner.gd               # Wave progression and horde perimeter spawner
    ├── main_level.gd            # Procedural terrain, railway tracks, and hazard platforms
    └── hud.gd                   # HUD signals, health bar, and game-over overlay
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
2. Click **Import** and select the `project.godot` file in this directory.
3. Click **Run Project** (`F5`) to play `scenes/MainLevel.tscn`.

### Exporting
* **Windows Desktop**: Project -> Export -> Select `Windows Desktop` -> Export Project (`Builds/Windows/Outbreak.exe`).
* **Android**: Project -> Export -> Select `Android` -> Export Project (`Builds/Android/Outbreak.apk`).
