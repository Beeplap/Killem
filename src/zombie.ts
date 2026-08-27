import type { Zombie, ZombieType, Vector2 } from './types';
import { normalize, distanceSq } from './math';
import { sprites } from './sprites';

export function createZombie(
  id: number,
  type: ZombieType,
  x: number,
  y: number,
  waveMultiplier: number = 1
): Zombie {
  let radius = 16;
  let speed = 95;
  let health = 100;
  let damage = 20;
  let color = '#4d7c0f';
  let scoreValue = 100;

  if (type === 'dog') {
    radius = 13;
    speed = 195;
    health = 45;
    damage = 15;
    color = '#78350f';
    scoreValue = 120;
  } else if (type === 'heavy') {
    radius = 27;
    speed = 48;
    health = 380;
    damage = 40;
    color = '#1f2937';
    scoreValue = 300;
  }

  speed *= (0.92 + Math.random() * 0.16) * Math.min(1.4, 1 + waveMultiplier * 0.035);
  health = Math.round(health * Math.min(2.4, 1 + waveMultiplier * 0.07));

  return {
    id,
    type,
    x,
    y,
    vx: 0,
    vy: 0,
    radius,
    speed,
    health,
    maxHealth: health,
    damage,
    active: true,
    color,
    wobblePhase: Math.random() * Math.PI * 2,
    wobbleSpeed: type === 'dog' ? 14 : (type === 'heavy' ? 3 : 6),
    scoreValue,
    hitFlashTimer: 0,
  };
}

export class ZombieManager {
  public zombies: Zombie[] = [];
  private nextId: number = 1;

  public update(dt: number, playerPos: Vector2): void {
    const pX = playerPos.x;
    const pY = playerPos.y;

    for (let i = 0; i < this.zombies.length; i++) {
      const z = this.zombies[i];
      if (!z.active) continue;

      if (z.hitFlashTimer > 0) {
        z.hitFlashTimer -= dt;
      }

      const dir = normalize(pX - z.x, pY - z.y);

      // Separation force
      let sepX = 0;
      let sepY = 0;

      for (let j = 0; j < this.zombies.length; j++) {
        if (i === j) continue;
        const other = this.zombies[j];
        if (!other.active) continue;

        const d2 = distanceSq(z.x, z.y, other.x, other.y);
        const minD = z.radius + other.radius + 4;
        if (d2 < minD * minD && d2 > 0.001) {
          const d = Math.sqrt(d2);
          const push = (minD - d) / minD;
          sepX += ((z.x - other.x) / d) * push;
          sepY += ((z.y - other.y) / d) * push;
        }
      }

      const sepWeight = z.type === 'dog' ? 0.25 : (z.type === 'heavy' ? 0.15 : 0.5);
      const combinedDir = normalize(dir.x + sepX * sepWeight, dir.y + sepY * sepWeight);

      z.vx = combinedDir.x * z.speed;
      z.vy = combinedDir.y * z.speed;

      z.x += z.vx * dt;
      z.y += z.vy * dt;

      z.wobblePhase += z.wobbleSpeed * dt;
    }

    if (this.zombies.length > 500) {
      this.zombies = this.zombies.filter((z) => z.active);
    }
  }

  public spawnZombie(type: ZombieType, x: number, y: number, waveMultiplier: number = 1): Zombie {
    let zombie = this.zombies.find((z) => !z.active);
    if (zombie) {
      const fresh = createZombie(zombie.id, type, x, y, waveMultiplier);
      Object.assign(zombie, fresh);
    } else {
      zombie = createZombie(this.nextId++, type, x, y, waveMultiplier);
      this.zombies.push(zombie);
    }
    return zombie;
  }

  public draw(ctx: CanvasRenderingContext2D, playerPos: Vector2): void {
    ctx.save();
    ctx.imageSmoothingEnabled = false;

    for (let i = 0; i < this.zombies.length; i++) {
      const z = this.zombies[i];
      if (!z.active) continue;

      ctx.save();
      ctx.translate(z.x, z.y);

      const angle = Math.atan2(playerPos.y - z.y, playerPos.x - z.x);
      ctx.rotate(angle);

      // Hit flash
      if (z.hitFlashTimer > 0) {
        ctx.filter = 'brightness(2.2)';
      }

      // Render pixel art sprite
      const frame = Math.floor(z.wobblePhase) % 2;
      const sprite = sprites.getSprite(`zombie_${z.type}_${frame}`);

      if (sprite) {
        if (z.type === 'dog') {
          ctx.drawImage(sprite, -18, -14, 38, 28);
        } else if (z.type === 'heavy') {
          ctx.drawImage(sprite, -27, -27, 54, 54);
        } else {
          ctx.drawImage(sprite, -18, -18, 36, 36);
        }
      }

      ctx.restore();

      // Health bar above zombie if injured
      if (z.health < z.maxHealth) {
        const barW = z.radius * 2;
        const barH = z.type === 'heavy' ? 5 : 4;
        const barX = z.x - barW / 2;
        const barY = z.y - z.radius - 12;
        const healthPercent = Math.max(0, z.health / z.maxHealth);

        ctx.fillStyle = 'rgba(0, 0, 0, 0.75)';
        ctx.fillRect(barX - 1, barY - 1, barW + 2, barH + 2);

        ctx.fillStyle = healthPercent > 0.4 ? '#22c55e' : '#ef4444';
        ctx.fillRect(barX, barY, barW * healthPercent, barH);
      }
    }

    ctx.restore();
  }

  public getActiveZombies(): Zombie[] {
    return this.zombies.filter((z) => z.active);
  }

  public reset(): void {
    for (let i = 0; i < this.zombies.length; i++) {
      this.zombies[i].active = false;
    }
  }
}
