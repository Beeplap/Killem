import type { DestructibleType, Particle, Vector2, ZombieType } from './types';
import { ObjectPool } from './pool';

export class ParticleSystem {
  public pool: ObjectPool<Particle>;
  private decalCanvas: HTMLCanvasElement;
  private decalCtx: CanvasRenderingContext2D;

  constructor(maxParticles: number = 550) {
    this.pool = new ObjectPool<Particle>(
      () => ({
        x: 0,
        y: 0,
        vx: 0,
        vy: 0,
        radius: 2,
        color: '#dc2626',
        alpha: 1,
        decay: 2,
        active: false,
      }),
      maxParticles
    );

    this.decalCanvas = document.createElement('canvas');
    this.decalCtx = this.decalCanvas.getContext('2d')!;
  }

  public initDecals(mapWidth: number, mapHeight: number): void {
    this.decalCanvas.width = mapWidth;
    this.decalCanvas.height = mapHeight;
    this.decalCtx.clearRect(0, 0, mapWidth, mapHeight);
  }

  public clearDecals(): void {
    this.decalCtx.clearRect(0, 0, this.decalCanvas.width, this.decalCanvas.height);
  }

  public update(dt: number): void {
    this.pool.forEachActive((p) => {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.93; // air resistance
      p.vy *= 0.93;
      p.alpha -= p.decay * dt;

      if (p.alpha <= 0) {
        this.pool.release(p);
      }
    });
  }

  /**
   * Spawns flying blood particles upon bullet hit
   */
  public spawnBlood(x: number, y: number, hitDirX: number, hitDirY: number, count: number = 8): void {
    for (let i = 0; i < count; i++) {
      const p = this.pool.acquire();
      p.x = x;
      p.y = y;

      const spread = (Math.random() - 0.5) * 1.6;
      const speed = 70 + Math.random() * 200;
      const cos = Math.cos(spread);
      const sin = Math.sin(spread);
      p.vx = (hitDirX * cos - hitDirY * sin) * speed;
      p.vy = (hitDirX * sin + hitDirY * cos) * speed;

      p.radius = 1.5 + Math.random() * 3.5;
      p.color = Math.random() > 0.35 ? '#991b1b' : '#dc2626';
      p.alpha = 1;
      p.decay = 1.6 + Math.random() * 2.2;
    }
  }

  /**
   * Spawns rich blood splatter particle burst on zombie death
   * and bakes permanent blood splats directly onto the floor decal canvas.
   */
  public spawnDeathBlood(
    x: number,
    y: number,
    hitDirX: number,
    hitDirY: number,
    zombieType: ZombieType
  ): void {
    let particleCount = 20;
    let poolRadius = 22;
    let streakCount = 10;

    if (zombieType === 'dog') {
      particleCount = 15;
      poolRadius = 18;
      streakCount = 8;
    } else if (zombieType === 'heavy') {
      particleCount = 42;
      poolRadius = 42;
      streakCount = 20;
    }

    // Dynamic flying blood particles
    for (let i = 0; i < particleCount; i++) {
      const p = this.pool.acquire();
      p.x = x;
      p.y = y;

      const spread = (Math.random() - 0.5) * 2.2;
      const speed = 80 + Math.random() * 260;
      const cos = Math.cos(spread);
      const sin = Math.sin(spread);
      p.vx = (hitDirX * cos - hitDirY * sin) * speed;
      p.vy = (hitDirX * sin + hitDirY * cos) * speed;

      p.radius = 2 + Math.random() * 4.5;
      p.color = Math.random() > 0.4 ? '#7f1d1d' : '#991b1b';
      p.alpha = 1;
      p.decay = 1.2 + Math.random() * 1.5;
    }

    // Permanent blood decal baked into map floor
    this.bakeBloodDecal(x, y, hitDirX, hitDirY, poolRadius, streakCount);
  }

  /**
   * Bakes a permanent organic blood pool with directional splatter streaks onto floor decal canvas.
   */
  private bakeBloodDecal(
    x: number,
    y: number,
    hitDirX: number,
    hitDirY: number,
    radius: number,
    streakCount: number
  ): void {
    const ctx = this.decalCtx;
    ctx.save();
    ctx.translate(x, y);

    // Layer 1: Dark coagulated necrotic blood core
    ctx.fillStyle = 'rgba(69, 10, 10, 0.72)';
    ctx.beginPath();
    const corePoints = 9;
    for (let i = 0; i < corePoints; i++) {
      const angle = (i / corePoints) * Math.PI * 2;
      const dist = radius * 0.7 * (0.6 + Math.random() * 0.8);
      const px = Math.cos(angle) * dist;
      const py = Math.sin(angle) * dist;
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fill();

    // Layer 2: Main arterial blood pool
    ctx.fillStyle = 'rgba(153, 27, 27, 0.62)';
    ctx.beginPath();
    const points = 11;
    for (let i = 0; i < points; i++) {
      const angle = (i / points) * Math.PI * 2;
      const dist = radius * (0.7 + Math.random() * 0.6);
      const px = Math.cos(angle) * dist;
      const py = Math.sin(angle) * dist;
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fill();

    // Layer 3: High-velocity arterial blood streaks pointing in hit direction
    const hitAngle = Math.atan2(hitDirY, hitDirX);
    ctx.fillStyle = 'rgba(127, 29, 29, 0.65)';

    for (let s = 0; s < streakCount; s++) {
      const sAngle = hitAngle + (Math.random() - 0.5) * 1.5;
      const sDist = radius * (1.1 + Math.random() * 1.8);
      const sLen = 4 + Math.random() * 14;
      const sWidth = 1.5 + Math.random() * 3.5;

      ctx.save();
      ctx.rotate(sAngle);
      ctx.beginPath();
      ctx.ellipse(sDist, 0, sLen, sWidth, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // Layer 4: Satellite droplets spattered around
    const dropletCount = 8 + Math.floor(Math.random() * 9);
    for (let d = 0; d < dropletCount; d++) {
      const dAngle = Math.random() * Math.PI * 2;
      const dDist = radius * (0.9 + Math.random() * 1.8);
      const dRad = 1.2 + Math.random() * 2.8;

      ctx.beginPath();
      ctx.arc(Math.cos(dAngle) * dDist, Math.sin(dAngle) * dDist, dRad, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  /**
   * Spawns destruction particles when crates, barrels, or trash bags break
   */
  public spawnDebris(
    x: number,
    y: number,
    type: DestructibleType,
    hitDir: Vector2,
    count: number = 12
  ): void {
    const colors =
      type === 'crate'
        ? ['#b45309', '#92400e', '#78350f', '#fde047']
        : type === 'barrel'
        ? ['#a16207', '#713f12', '#475569', '#334155']
        : ['#0f172a', '#1e293b', '#334155', '#eab308'];

    for (let i = 0; i < count; i++) {
      const p = this.pool.acquire();
      p.x = x + (Math.random() - 0.5) * 16;
      p.y = y + (Math.random() - 0.5) * 16;

      const angle = Math.atan2(hitDir.y, hitDir.x) + (Math.random() - 0.5) * 2.4;
      const speed = 60 + Math.random() * 180;
      p.vx = Math.cos(angle) * speed;
      p.vy = Math.sin(angle) * speed;

      p.radius = type === 'trash' ? 1.5 + Math.random() * 2.5 : 2 + Math.random() * 4;
      p.color = colors[Math.floor(Math.random() * colors.length)];
      p.alpha = 1;
      p.decay = 1.8 + Math.random() * 2.0;
    }
  }

  /**
   * Spawns muzzle flash spark particles
   */
  public spawnMuzzleSparks(x: number, y: number, dirX: number, dirY: number): void {
    for (let i = 0; i < 4; i++) {
      const p = this.pool.acquire();
      p.x = x;
      p.y = y;
      const angle = (Math.random() - 0.5) * 0.8;
      const speed = 120 + Math.random() * 160;
      p.vx = (dirX * Math.cos(angle) - dirY * Math.sin(angle)) * speed;
      p.vy = (dirX * Math.sin(angle) + dirY * Math.cos(angle)) * speed;
      p.radius = 1.5 + Math.random() * 1.5;
      p.color = '#fbbf24';
      p.alpha = 1;
      p.decay = 7;
    }
  }

  public drawDecals(ctx: CanvasRenderingContext2D): void {
    ctx.drawImage(this.decalCanvas, 0, 0);
  }

  public drawParticles(ctx: CanvasRenderingContext2D): void {
    ctx.save();
    this.pool.forEachActive((p) => {
      ctx.globalAlpha = Math.max(0, p.alpha);
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.restore();
  }

  public reset(): void {
    this.pool.releaseAll();
    this.clearDecals();
  }
}
