import type { WeaponType } from './types';

/**
 * Procedural Pixel Art Sprite Generator.
 * Generates authentic retro pixel art sprites (Player, Zombies, Dogs, Crates, Barrels, Trash)
 * with nearest-neighbor crisp rendering and zero external image asset dependencies.
 */
class SpriteSheetManager {
  private cache: Map<string, HTMLCanvasElement> = new Map();

  constructor() {
    this.generateAllSprites();
  }

  private createPixelCanvas(width: number, height: number): { canvas: HTMLCanvasElement; ctx: CanvasRenderingContext2D } {
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d')!;
    ctx.imageSmoothingEnabled = false;
    return { canvas, ctx };
  }

  private generateAllSprites(): void {
    // 1. Generate Player Sprites (for each weapon: pistol, shotgun, rifle, and 2 walk frames)
    const weapons: WeaponType[] = ['pistol', 'shotgun', 'rifle'];
    for (const w of weapons) {
      for (let frame = 0; frame < 2; frame++) {
        this.cache.set(`player_${w}_${frame}`, this.generatePlayerSprite(w, frame));
      }
    }

    // 2. Generate Zombie Sprites (regular, dog, heavy with walk frames)
    for (let frame = 0; frame < 2; frame++) {
      this.cache.set(`zombie_regular_${frame}`, this.generateRegularZombieSprite(frame));
      this.cache.set(`zombie_dog_${frame}`, this.generateInfectedDogSprite(frame));
      this.cache.set(`zombie_heavy_${frame}`, this.generateHeavyZombieSprite(frame));
    }

    // 3. Generate Destructible Objects
    this.cache.set('destructible_crate', this.generateCrateSprite());
    this.cache.set('destructible_barrel', this.generateBarrelSprite());
    this.cache.set('destructible_trash', this.generateTrashSprite());
  }

  // ==========================================
  // PLAYER PIXEL SPRITE
  // ==========================================
  private generatePlayerSprite(weapon: WeaponType, frame: number): HTMLCanvasElement {
    const { canvas, ctx } = this.createPixelCanvas(36, 36);

    ctx.save();
    ctx.translate(18, 18);

    // Pixel shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
    ctx.fillRect(-10, -8, 20, 16);

    // Tactical Boots / Legs (animated walk)
    const legOffset = frame === 1 ? 4 : -4;
    ctx.fillStyle = '#0f172a'; // Black boots
    ctx.fillRect(-12, -7 + legOffset, 7, 5);
    ctx.fillRect(-12, 2 - legOffset, 7, 5);

    // Commando Torso (Navy tactical vest)
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(-9, -8, 14, 16);
    ctx.fillStyle = '#334155'; // Armor plate
    ctx.fillRect(-7, -6, 10, 12);

    // Utility belt pouches
    ctx.fillStyle = '#64748b';
    ctx.fillRect(-9, -7, 2, 4);
    ctx.fillRect(-9, 3, 2, 4);

    // Shoulders
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(-6, -10, 8, 4);
    ctx.fillRect(-6, 6, 8, 4);

    // Hands
    ctx.fillStyle = '#fed7aa'; // Skin tone
    ctx.fillRect(2, -7, 4, 4);
    ctx.fillRect(8, 2, 4, 4);

    // Weapon
    if (weapon === 'shotgun') {
      // 12-Gauge Shotgun (long wooden stock + dual metal barrel)
      ctx.fillStyle = '#78350f'; // Wood stock
      ctx.fillRect(2, 2, 5, 4);
      ctx.fillStyle = '#0f172a'; // Receiver
      ctx.fillRect(7, 1, 6, 5);
      ctx.fillStyle = '#64748b'; // Dual barrel
      ctx.fillRect(13, 1, 9, 4);
      ctx.fillStyle = '#94a3b8'; // Muzzle tip
      ctx.fillRect(22, 2, 2, 3);
    } else if (weapon === 'rifle') {
      // Assault Rifle (long receiver, magazine, suppressor)
      ctx.fillStyle = '#0f172a';
      ctx.fillRect(3, 2, 16, 4);
      ctx.fillStyle = '#334155'; // Mag
      ctx.fillRect(8, 5, 4, 5);
      ctx.fillStyle = '#475569'; // Handguard
      ctx.fillRect(10, 1, 7, 5);
      ctx.fillStyle = '#0284c7'; // Suppressor
      ctx.fillRect(19, 3, 5, 2);
    } else {
      // 9mm Handgun
      ctx.fillStyle = '#0f172a';
      ctx.fillRect(4, 2, 10, 4);
      ctx.fillStyle = '#94a3b8';
      ctx.fillRect(12, 3, 3, 2);
    }

    // Tactical Helmet (Swat Kevlar)
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(-6, -5, 10, 10);
    // Cyan Visor reflection (signature look from reference)
    ctx.fillStyle = '#38bdf8';
    ctx.fillRect(1, -3, 3, 6);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(2, -2, 1, 2);

    ctx.restore();
    return canvas;
  }

  // ==========================================
  // REGULAR ZOMBIE PIXEL SPRITE
  // ==========================================
  private generateRegularZombieSprite(frame: number): HTMLCanvasElement {
    const { canvas, ctx } = this.createPixelCanvas(36, 36);

    ctx.save();
    ctx.translate(18, 18);

    // Shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
    ctx.fillRect(-8, -8, 18, 16);

    const step = frame === 1 ? 3 : -3;

    // Tattered civilian pants (classic Zombie Shooter infected)
    ctx.fillStyle = '#1e1b4b'; // Dirty indigo jeans
    ctx.fillRect(-11, -6 + step, 6, 4);
    ctx.fillRect(-11, 2 - step, 6, 4);

    // Decayed Torso (ripped shirt + exposed rotten flesh)
    ctx.fillStyle = '#365314'; // Rotten flesh green
    ctx.fillRect(-8, -7, 12, 14);
    ctx.fillStyle = '#581c87'; // Ripped purple shirt remnants
    ctx.fillRect(-7, -7, 6, 14);
    ctx.fillStyle = '#991b1b'; // Bloody chest wound
    ctx.fillRect(-4, -2, 4, 5);

    // Outstretched grasping arms with bloodied claws
    const armWobble = frame === 1 ? 2 : -2;
    ctx.fillStyle = '#365314';
    // Left arm
    ctx.fillRect(-3, -11, 14 + armWobble, 4);
    ctx.fillStyle = '#7f1d1d'; // bloody claws
    ctx.fillRect(11 + armWobble, -11, 4, 4);

    // Right arm
    ctx.fillStyle = '#365314';
    ctx.fillRect(-3, 7, 14 - armWobble, 4);
    ctx.fillStyle = '#7f1d1d';
    ctx.fillRect(11 - armWobble, 7, 4, 4);

    // Decayed Head
    ctx.fillStyle = '#365314';
    ctx.fillRect(-5, -5, 9, 10);
    // Sunken bloodshot eyes
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(2, -3, 2, 2);
    ctx.fillRect(2, 2, 2, 2);
    // Bloody snarling mouth
    ctx.fillStyle = '#7f1d1d';
    ctx.fillRect(3, -1, 2, 3);

    ctx.restore();
    return canvas;
  }

  // ==========================================
  // INFECTED DOG PIXEL SPRITE
  // ==========================================
  private generateInfectedDogSprite(frame: number): HTMLCanvasElement {
    const { canvas, ctx } = this.createPixelCanvas(38, 28);

    ctx.save();
    ctx.translate(18, 14);

    // Shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
    ctx.fillRect(-14, -6, 26, 12);

    const paw = frame === 1 ? 4 : -4;

    // Quadruped Paws (scuttling)
    ctx.fillStyle = '#451a03';
    // Front paws
    ctx.fillRect(6, -8 + paw, 5, 3);
    ctx.fillRect(6, 5 - paw, 5, 3);
    // Hind paws
    ctx.fillRect(-12, -7 - paw, 5, 3);
    ctx.fillRect(-12, 4 + paw, 5, 3);

    // Elongated feral body
    ctx.fillStyle = '#78350f'; // Decayed brown fur
    ctx.fillRect(-10, -5, 18, 10);

    // Exposed bloody spine / torn flesh
    ctx.fillStyle = '#991b1b';
    ctx.fillRect(-6, -2, 10, 4);
    ctx.fillStyle = '#f87171'; // Bone vertebrae
    ctx.fillRect(-5, -1, 8, 2);

    // Mutilated twitching tail
    ctx.fillStyle = '#451a03';
    ctx.fillRect(-14, -2 + (frame === 1 ? 2 : -2), 5, 3);

    // Snout / Head
    ctx.fillStyle = '#451a03';
    ctx.fillRect(7, -4, 8, 8);
    // Pointed feral ears
    ctx.fillStyle = '#991b1b';
    ctx.fillRect(6, -6, 3, 3);
    ctx.fillRect(6, 4, 3, 3);

    // Snapping jaws & needle teeth
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(13, -2, 4, 4);
    ctx.fillStyle = '#ffffff'; // Fangs
    ctx.fillRect(14, -3, 2, 1);
    ctx.fillRect(14, 2, 2, 1);

    // Rabid yellow eyes
    ctx.fillStyle = '#f59e0b';
    ctx.fillRect(9, -3, 2, 2);
    ctx.fillRect(9, 2, 2, 2);

    ctx.restore();
    return canvas;
  }

  // ==========================================
  // HEAVY ZOMBIE PIXEL SPRITE
  // ==========================================
  private generateHeavyZombieSprite(frame: number): HTMLCanvasElement {
    const { canvas, ctx } = this.createPixelCanvas(54, 54);

    ctx.save();
    ctx.translate(27, 27);

    // Large shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
    ctx.fillRect(-16, -16, 34, 32);

    const heavyStep = frame === 1 ? 3 : -3;

    // Massive boots
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(-18, -12 + heavyStep, 10, 7);
    ctx.fillRect(-18, 5 - heavyStep, 10, 7);

    // Hulking back & bone spikes
    ctx.fillStyle = '#111827';
    ctx.fillRect(-15, -13, 10, 26);
    ctx.fillStyle = '#cbd5e1'; // Bone spikes
    ctx.fillRect(-19, -9, 5, 4);
    ctx.fillRect(-19, -1, 5, 4);
    ctx.fillRect(-19, 7, 5, 4);

    // Massive mutated torso
    ctx.fillStyle = '#1f2937';
    ctx.fillRect(-12, -13, 20, 26);
    ctx.fillStyle = '#374151';
    ctx.fillRect(-9, -10, 14, 20);

    // Mutated muscular shoulders
    ctx.fillStyle = '#111827';
    ctx.fillRect(-4, -18, 12, 7);
    ctx.fillRect(-4, 11, 12, 7);

    // Heavy mutated crushing arms & fists
    ctx.fillStyle = '#1f2937';
    ctx.fillRect(5, -16, 14, 7);
    ctx.fillRect(5, 9, 14, 7);
    // Spiked fists
    ctx.fillStyle = '#991b1b';
    ctx.fillRect(17, -17, 7, 8);
    ctx.fillRect(17, 8, 7, 8);

    // Sunken mutant head
    ctx.fillStyle = '#030712';
    ctx.fillRect(-3, -7, 10, 14);

    // Glowing crimson brute eyes
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(5, -4, 3, 3);
    ctx.fillRect(5, 2, 3, 3);

    ctx.restore();
    return canvas;
  }

  // ==========================================
  // DESTRUCTIBLES (Crate, Barrel, Trash)
  // ==========================================
  private generateCrateSprite(): HTMLCanvasElement {
    const { canvas, ctx } = this.createPixelCanvas(32, 32);

    // Dark border
    ctx.fillStyle = '#1e1b18';
    ctx.fillRect(0, 0, 32, 32);

    // Wooden background planks
    ctx.fillStyle = '#92400e';
    ctx.fillRect(2, 2, 28, 28);

    // Plank seams
    ctx.fillStyle = '#78350f';
    ctx.fillRect(2, 10, 28, 2);
    ctx.fillRect(2, 20, 28, 2);

    // Wooden cross braces
    ctx.fillStyle = '#b45309';
    ctx.beginPath();
    ctx.moveTo(2, 2);
    ctx.lineTo(6, 2);
    ctx.lineTo(30, 26);
    ctx.lineTo(30, 30);
    ctx.lineTo(26, 30);
    ctx.lineTo(2, 6);
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(30, 2);
    ctx.lineTo(26, 2);
    ctx.lineTo(2, 26);
    ctx.lineTo(2, 30);
    ctx.lineTo(6, 30);
    ctx.lineTo(30, 6);
    ctx.fill();

    // Corner metal brackets with rivets
    ctx.fillStyle = '#475569';
    // Top-left
    ctx.fillRect(2, 2, 7, 2);
    ctx.fillRect(2, 2, 2, 7);
    // Top-right
    ctx.fillRect(23, 2, 7, 2);
    ctx.fillRect(28, 2, 2, 7);
    // Bottom-left
    ctx.fillRect(2, 28, 7, 2);
    ctx.fillRect(2, 23, 2, 7);
    // Bottom-right
    ctx.fillRect(23, 28, 7, 2);
    ctx.fillRect(28, 23, 2, 7);

    // Golden rivets
    ctx.fillStyle = '#fde047';
    ctx.fillRect(3, 3, 2, 2);
    ctx.fillRect(27, 3, 2, 2);
    ctx.fillRect(3, 27, 2, 2);
    ctx.fillRect(27, 27, 2, 2);

    return canvas;
  }

  private generateBarrelSprite(): HTMLCanvasElement {
    const { canvas, ctx } = this.createPixelCanvas(30, 30);

    // Dark shadow / outline
    ctx.fillStyle = '#1c1917';
    ctx.beginPath();
    ctx.arc(15, 15, 14, 0, Math.PI * 2);
    ctx.fill();

    // Wood stave top
    ctx.fillStyle = '#a16207';
    ctx.beginPath();
    ctx.arc(15, 15, 12, 0, Math.PI * 2);
    ctx.fill();

    // Wood plank radial lines
    ctx.strokeStyle = '#713f12';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(3, 15);
    ctx.lineTo(27, 15);
    ctx.moveTo(15, 3);
    ctx.lineTo(15, 27);
    ctx.stroke();

    // Outer iron hoop band
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(15, 15, 11, 0, Math.PI * 2);
    ctx.stroke();

    // Inner bung hole / rivet
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(18, 13, 4, 4);

    return canvas;
  }

  private generateTrashSprite(): HTMLCanvasElement {
    const { canvas, ctx } = this.createPixelCanvas(32, 28);

    // Ground shadow
    ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
    ctx.fillRect(2, 14, 28, 12);

    // Black plastic garbage bag body (lumpy irregular pixel bag)
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(4, 8, 24, 16);
    ctx.fillRect(6, 4, 20, 20);
    ctx.fillRect(8, 2, 16, 24);

    // Plastic shine / highlights
    ctx.fillStyle = '#334155';
    ctx.fillRect(6, 6, 12, 3);
    ctx.fillRect(18, 12, 7, 3);
    ctx.fillRect(8, 17, 8, 3);

    // Bright specular glint
    ctx.fillStyle = '#94a3b8';
    ctx.fillRect(8, 7, 4, 1);
    ctx.fillRect(19, 13, 3, 1);

    // Yellow twist-tie knot at top
    ctx.fillStyle = '#eab308';
    ctx.fillRect(14, 1, 4, 4);
    ctx.fillRect(13, 0, 2, 2);
    ctx.fillRect(17, 0, 2, 2);

    return canvas;
  }

  public getSprite(key: string): HTMLCanvasElement | undefined {
    return this.cache.get(key);
  }
}

export const sprites = new SpriteSheetManager();
