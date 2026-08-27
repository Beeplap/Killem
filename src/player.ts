import type { Vector2, WeaponType } from './types';
import { clamp, normalize } from './math';
import { sprites } from './sprites';

export class Player {
  public x: number = 0;
  public y: number = 0;
  public radius: number = 16;
  public speed: number = 245; // pixels per second
  public maxHealth: number = 100;
  public health: number = 100;
  public angle: number = 0; // aim angle in radians

  public invulnerableTimer: number = 0;
  public readonly invulnerableDuration: number = 0.5; // seconds
  public isDead: boolean = false;

  private walkPhase: number = 0;
  private isMoving: boolean = false;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }

  public reset(x: number, y: number): void {
    this.x = x;
    this.y = y;
    this.health = this.maxHealth;
    this.invulnerableTimer = 0;
    this.isDead = false;
    this.angle = 0;
    this.walkPhase = 0;
    this.isMoving = false;
  }

  public heal(amount: number): number {
    if (this.isDead) return 0;
    const prev = this.health;
    this.health = Math.min(this.maxHealth, this.health + amount);
    return this.health - prev;
  }

  public update(
    dt: number,
    moveInput: Vector2,
    aimPos: Vector2 | null,
    aimAngle: number | null,
    mapWidth: number,
    mapHeight: number
  ): void {
    if (this.isDead) return;

    if (this.invulnerableTimer > 0) {
      this.invulnerableTimer -= dt;
    }

    const inputDir = normalize(moveInput.x, moveInput.y);
    if (inputDir.x !== 0 || inputDir.y !== 0) {
      this.x += inputDir.x * this.speed * dt;
      this.y += inputDir.y * this.speed * dt;
      this.walkPhase += dt * 10;
      this.isMoving = true;
    } else {
      this.isMoving = false;
    }

    // Clamp inside world boundaries
    this.x = clamp(this.x, this.radius + 20, mapWidth - this.radius - 20);
    this.y = clamp(this.y, this.radius + 20, mapHeight - this.radius - 20);

    // Update aim angle
    if (aimAngle !== null) {
      this.angle = aimAngle;
    } else if (aimPos !== null) {
      this.angle = Math.atan2(aimPos.y - this.y, aimPos.x - this.x);
    }
  }

  /**
   * Returns muzzle position in world coordinates for spawning bullets
   */
  public getMuzzlePosition(weaponType: WeaponType = 'pistol'): Vector2 {
    let barrelLength = this.radius + 10;
    if (weaponType === 'shotgun') barrelLength = this.radius + 15;
    if (weaponType === 'rifle') barrelLength = this.radius + 18;

    const cos = Math.cos(this.angle);
    const sin = Math.sin(this.angle);

    return {
      x: this.x + cos * barrelLength,
      y: this.y + sin * barrelLength,
    };
  }

  public takeDamage(amount: number, knockbackDir?: Vector2): boolean {
    if (this.isDead || this.invulnerableTimer > 0) {
      return false;
    }

    this.health -= amount;
    this.invulnerableTimer = this.invulnerableDuration;

    if (knockbackDir) {
      this.x += knockbackDir.x * 14;
      this.y += knockbackDir.y * 14;
    }

    if (this.health <= 0) {
      this.health = 0;
      this.isDead = true;
    }
    return true;
  }

  public draw(ctx: CanvasRenderingContext2D, weaponType: WeaponType = 'pistol'): void {
    if (this.isDead) return;

    ctx.save();
    ctx.translate(this.x, this.y);
    // Rotate so sprite (drawn pointing UP) faces mouse aim vector directly upright
    ctx.rotate(this.angle + Math.PI / 2);

    // Flash when invulnerable
    if (this.invulnerableTimer > 0 && Math.floor(this.invulnerableTimer * 20) % 2 === 0) {
      ctx.globalAlpha = 0.4;
    }

    // Pixel Art Sprite Render
    const frame = this.isMoving ? Math.floor(this.walkPhase) % 2 : 0;
    const sprite = sprites.getSprite(`player_${weaponType}_${frame}`);

    if (sprite) {
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(sprite, -19, -19, 38, 38);
    }

    ctx.restore();
  }
}
