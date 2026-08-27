import type { Pickup, PickupType, Vector2 } from './types';
import { distanceSq } from './math';
import { sound } from './audio';

export class PickupManager {
  public pickups: Pickup[] = [];
  private nextId: number = 1;

  public reset(): void {
    this.pickups = [];
  }

  public maybeSpawnPickup(x: number, y: number, isHeavy: boolean = false): void {
    // 30% drop chance for normal zombies, 80% for heavy zombies
    const chance = isHeavy ? 0.85 : 0.28;
    if (Math.random() > chance) return;

    // 70% ammo, 30% medkit
    const type: PickupType = Math.random() < 0.7 ? 'ammo' : 'medkit';

    this.pickups.push({
      id: this.nextId++,
      type,
      x,
      y,
      radius: 14,
      active: true,
      lifetime: 20, // 20 seconds before despawn
      bobPhase: Math.random() * Math.PI * 2,
    });
  }

  public update(
    dt: number,
    playerPos: Vector2,
    playerRadius: number,
    onCollect: (type: PickupType) => void
  ): void {
    for (let i = 0; i < this.pickups.length; i++) {
      const p = this.pickups[i];
      if (!p.active) continue;

      p.lifetime -= dt;
      p.bobPhase += dt * 3.5;

      if (p.lifetime <= 0) {
        p.active = false;
        continue;
      }

      // Check collision with player
      const d2 = distanceSq(p.x, p.y, playerPos.x, playerPos.y);
      const grabRadius = p.radius + playerRadius + 6;
      if (d2 <= grabRadius * grabRadius) {
        p.active = false;
        sound.playPickup();
        onCollect(p.type);
      }
    }

    // Filter dead pickups
    if (this.pickups.length > 50) {
      this.pickups = this.pickups.filter((p) => p.active);
    }
  }

  public draw(ctx: CanvasRenderingContext2D): void {
    ctx.save();

    for (let i = 0; i < this.pickups.length; i++) {
      const p = this.pickups[i];
      if (!p.active) continue;

      const bobY = Math.sin(p.bobPhase) * 3;
      const x = p.x;
      const y = p.y + bobY;

      // Despawn blink when under 4 seconds
      if (p.lifetime < 4 && Math.floor(p.lifetime * 6) % 2 === 0) {
        continue;
      }

      // Ground shadow
      ctx.beginPath();
      ctx.ellipse(x, p.y + 10, 12, 5, 0, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
      ctx.fill();

      // Outer glow pulse
      const glowColor = p.type === 'ammo' ? '#eab308' : '#22c55e';
      ctx.shadowColor = glowColor;
      ctx.shadowBlur = 10;

      if (p.type === 'ammo') {
        // Military Ammo Crate (Olive green / yellow crate with stencil text)
        ctx.fillStyle = '#854d0e';
        ctx.fillRect(x - 9, y - 7, 18, 14);

        ctx.fillStyle = '#eab308';
        ctx.fillRect(x - 7, y - 5, 14, 10);

        ctx.fillStyle = '#1e293b';
        ctx.fillRect(x - 8, y - 2, 16, 4);

        // Ammo bullet icon
        ctx.fillStyle = '#fef08a';
        ctx.fillRect(x - 4, y - 4, 3, 8);
        ctx.fillRect(x + 1, y - 4, 3, 8);
      } else {
        // Medical First Aid Kit (White box with red cross)
        ctx.fillStyle = '#f8fafc';
        ctx.beginPath();
        ctx.roundRect(x - 9, y - 8, 18, 16, 3);
        ctx.fill();

        // Red cross
        ctx.fillStyle = '#ef4444';
        ctx.fillRect(x - 2, y - 6, 4, 12);
        ctx.fillRect(x - 6, y - 2, 12, 4);
      }

      ctx.shadowBlur = 0;
    }

    ctx.restore();
  }
}
