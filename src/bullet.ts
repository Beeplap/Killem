import type { Bullet, Vector2, WeaponConfig } from './types';
import { ObjectPool } from './pool';
import { normalize } from './math';

export function createBulletFactory(): (id: number) => Bullet {
  return (id: number): Bullet => ({
    id,
    x: 0,
    y: 0,
    vx: 0,
    vy: 0,
    radius: 3.5,
    damage: 34,
    speed: 950,
    lifetime: 0,
    maxLifetime: 1.6,
    active: false,
    color: '#fffae0',
  });
}

export function resetBullet(bullet: Bullet): void {
  bullet.lifetime = 0;
  bullet.radius = 3.5;
  bullet.damage = 34;
  bullet.speed = 950;
  bullet.maxLifetime = 1.6;
  bullet.color = '#fffae0';
}

export class BulletSystem {
  public pool: ObjectPool<Bullet>;

  constructor(poolSize: number = 450) {
    this.pool = new ObjectPool<Bullet>(createBulletFactory(), poolSize, resetBullet);
  }

  public update(dt: number, screenWidth: number, screenHeight: number): void {
    this.pool.forEachActive((bullet) => {
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
      bullet.lifetime += dt;

      // Check lifespan or outside screen buffer
      const margin = 50;
      if (
        bullet.lifetime >= bullet.maxLifetime ||
        bullet.x < -margin ||
        bullet.x > screenWidth + margin ||
        bullet.y < -margin ||
        bullet.y > screenHeight + margin
      ) {
        this.pool.release(bullet);
      }
    });
  }

  /**
   * Fires one or multiple bullets (e.g. shotgun spread) according to weapon configuration.
   */
  public shootWeapon(origin: Vector2, target: Vector2, config: WeaponConfig): Bullet[] {
    let dir = normalize(target.x - origin.x, target.y - origin.y);
    if (dir.x === 0 && dir.y === 0) {
      dir = { x: 1, y: 0 };
    }

    const baseAngle = Math.atan2(dir.y, dir.x);
    const bullets: Bullet[] = [];

    const pellets = config.pellets;
    for (let p = 0; p < pellets; p++) {
      let angleOffset = 0;
      if (pellets > 1) {
        // Distributed fan cone for shotgun + small random jitter
        const fraction = p / (pellets - 1) - 0.5; // -0.5 to +0.5
        angleOffset = fraction * config.spread + (Math.random() - 0.5) * 0.06;
      } else {
        // Pinpoint shot with weapon spread variance
        angleOffset = (Math.random() - 0.5) * config.spread;
      }

      const shotAngle = baseAngle + angleOffset;
      const bullet = this.pool.acquire();

      bullet.x = origin.x;
      bullet.y = origin.y;
      bullet.radius = config.bulletRadius;
      bullet.damage = config.damage;
      bullet.speed = config.bulletSpeed * (0.95 + Math.random() * 0.1);
      bullet.maxLifetime = config.bulletLifetime * (0.9 + Math.random() * 0.2);
      bullet.lifetime = 0;

      bullet.vx = Math.cos(shotAngle) * bullet.speed;
      bullet.vy = Math.sin(shotAngle) * bullet.speed;

      if (config.id === 'shotgun') {
        bullet.color = '#fb923c'; // fiery shotgun pellet
      } else if (config.id === 'rifle') {
        bullet.color = '#fef08a'; // hyper velocity rifle tracer
      } else {
        bullet.color = '#fffae0'; // classic handgun bullet
      }

      bullets.push(bullet);
    }

    return bullets;
  }

  public draw(ctx: CanvasRenderingContext2D): void {
    ctx.save();

    this.pool.forEachActive((bullet) => {
      // Draw glowing tracer line behind bullet
      const tailLength = bullet.radius * 4.5;
      const speed = Math.hypot(bullet.vx, bullet.vy);
      if (speed > 0) {
        const nx = (bullet.vx / speed) * tailLength;
        const ny = (bullet.vy / speed) * tailLength;

        const grad = ctx.createLinearGradient(
          bullet.x - nx,
          bullet.y - ny,
          bullet.x,
          bullet.y
        );
        grad.addColorStop(0, 'rgba(255, 180, 50, 0)');
        grad.addColorStop(0.6, bullet.color || '#fffae0');
        grad.addColorStop(1, '#ffffff');

        ctx.strokeStyle = grad;
        ctx.lineWidth = bullet.radius * 0.9;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(bullet.x - nx, bullet.y - ny);
        ctx.lineTo(bullet.x, bullet.y);
        ctx.stroke();
      }

      // Glowing bullet head
      ctx.beginPath();
      ctx.arc(bullet.x, bullet.y, bullet.radius, 0, Math.PI * 2);
      ctx.fillStyle = '#ffffff';
      ctx.shadowColor = bullet.color || '#fbbf24';
      ctx.shadowBlur = 6;
      ctx.fill();
    });

    ctx.restore();
  }

  public reset(): void {
    this.pool.releaseAll();
  }
}
