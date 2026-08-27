# OUTBREAK // 2D Top-Down Zombie Survival

[![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=flat-square&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Vite](https://img.shields.io/badge/Vite-646CFF?style=flat-square&logo=vite&logoColor=white)](https://vitejs.dev/)
[![HTML5 Canvas](https://img.shields.io/badge/HTML5-Canvas%202D-E34F26?style=flat-square&logo=html5&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API)
[![Web Audio API](https://img.shields.io/badge/Web_Audio_API-Procedural%20SFX-orange?style=flat-square)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

> *"The quarantine protocol has failed. Evacuation is impossible. Scavenge for ammunition, hold your ground, and eliminate the infected horde."*

**OUTBREAK** is a fast-paced retro-arcade 2D top-down zombie shooter built from scratch with **TypeScript**, **HTML5 Canvas**, and **Vite**. It features 100% procedural pixel art, a custom Web Audio API sound synthesizer, sector-based compound exploration, destructible crates, and wave-based survival mechanics.

---

## 🎮 Play Online / Quick Preview

Run the development server locally:
```bash
git clone https://github.com/Beeplap/Killem.git
cd Killem
npm install
npm run dev
```
Open `http://localhost:5173` in any modern web browser to play.

---

## 🕹️ Controls

### Desktop (Keyboard & Mouse)

| Action | Key / Input |
| :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` or Arrow Keys |
| **Aim** | Mouse cursor position |
| **Fire Weapon** | Left Mouse Button (Hold for automatic fire) |
| **Select 9mm Pistol** | `1` |
| **Select 12-Gauge Shotgun** | `2` |
| **Select Assault Rifle** | `3` |
| **Manual Reload** | `R` |
| **Toggle Audio** | Sound button (Top-right) |

### Mobile & Touch Devices
- **Left Virtual Joystick**: Move soldier in 360 degrees.
- **Right Virtual Joystick / Tap**: Aim direction and automatic continuous firing.
- **Quick-Switch Weapon Bar**: Bottom-right on-screen buttons for switching weapons and monitoring ammo counts.

---

## ⚡ Key Features

### 1. 100% Procedural Pixel Art & Graphics
- **Zero external image dependencies**: Soldier, zombie breeds, guns, blood splatters, and environment tiles are rendered dynamically via canvas pixel buffers.
- **Tactical Soldier**: Detailed pixel SWAT commando with directional aiming, walking leg animations, tactical vest, and helmet visor glint.
- **Atmospheric Lighting**: Dark indoor research sectors contrasted with a rainy outdoor courtyard complete with droplet splashes and ambient fog.

### 2. Procedural Web Audio API Sound System
- **Real-Time Sound Synthesis**: Pure Web Audio oscillators, pink/white noise generators, and biquad filters synthesize:
  - Gunshot punch, mechanical receiver clicks, and brass shell-casing bounces.
  - Zombie throat groans, lunges, and blood squelches.
  - Wooden crate splintering and item pickup cues.
  - Deep ominous ambient compound drone.

### 3. Sector Exploration & Tactical CRT Radar
- **Compound Map Generation**: Explore connected rooms including Laboratories, Armory, Medical Bay, Generator Rooms, and an outdoor Yard.
- **Sector Entry Banners**: Visual industrial warning banner announces sector changes as you navigate the facility.
- **Circular CRT Radar Minimap**: Features rotating radar sweep line, room layout discovery, player GPS blip, crate drops, and enemy red pings.

### 4. Destructibles & Scavenger Loot System
- Break wooden crates, hazardous barrels, and debris throughout the compound.
- Dropped loot includes:
  - **Medkits**: Restore soldier health (+25 HP).
  - **Ammo Packs**: Replenish reserve magazines for Shotgun and Assault Rifle.

### 5. Multi-Threat Zombie Horde
- **Regular Walkers**: Shambling infected civilians that relentlessly swarm in groups.
- **Infected Canines / Runners**: Fast low-profile rush predators that dart around obstacles to flank the player.
- **Heavy Brutes**: Giant bullet-sponge mutants dealing massive crushing damage.

### 6. Lethal Weapon Arsenal
- **9mm Service Pistol**: Reliable sidearm with unlimited reserve ammunition.
- **12-Gauge Pump Shotgun**: High-spread buckshot lethal at point-blank range.
- **Tactical Assault Rifle**: Rapid-fire, pinpoint accuracy for thinning massive swarms.

### 7. Engine Performance & Optimization
- High-frequency **Object Pooling** for bullets, blood splatters, smoke, and zombies prevents garbage collection spikes and guarantees silky smooth 60+ FPS gameplay.

---

## 🛠️ Project Structure

```
game/
├── index.html              # HTML5 canvas container and retro arcade HUD
├── package.json            # Scripts and dependencies (TypeScript, Vite)
├── tsconfig.json           # Strict TypeScript configuration
├── public/                 # Favicons and web assets
└── src/
    ├── audio.ts            # Procedural Web Audio API synthesizer
    ├── bullet.ts           # Projectile trajectories and impact detection
    ├── destructibles.ts    # Crates, barrels, and loot drop management
    ├── game.ts             # Main loop, rendering pipeline, camera & HUD
    ├── joystick.ts         # Dual virtual analog joysticks for mobile
    ├── main.ts             # Application bootstrapping and DOM listeners
    ├── map.ts              # Procedural compound generation & rooms
    ├── math.ts             # Vector math, collisions (AABB, circle-rect)
    ├── particles.ts        # Particle emitter (blood, sparks, casings, rain)
    ├── pickups.ts          # Medkits, ammo crates, and item collection
    ├── player.ts           # Soldier entity, movement, aim, and stats
    ├── pool.ts             # Generic object pooling engine
    ├── spawner.ts          # Wave scaling and zombie distribution
    ├── sprites.ts          # Procedural pixel-art canvas sprite generator
    ├── style.css           # Arcade CRT HUD styling and responsive layout
    ├── types.ts            # Game data interfaces and type definitions
    └── weapons.ts          # Arsenal configurations and ballistics stats
```

---

## 🚀 Development & Build

### Prerequisites
- [Node.js](https://nodejs.org/) (version 18 or higher recommended)
- [npm](https://www.npmjs.com/) or [pnpm](https://pnpm.io/)

### Install Dependencies
```bash
npm install
```

### Start Development Server
```bash
npm run dev
```

### Build for Production
```bash
npm run build
```
The compiled, type-checked production bundle will be output into the `dist/` directory.

### Preview Production Build
```bash
npm run preview
```

---

## 📄 License
This project is open-source under the [MIT License](LICENSE).
