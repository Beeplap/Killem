import type { DestructibleObject, PickupType, Vector2 } from './types';
import { sprites } from './sprites';
import { ParticleSystem } from './particles';
import { sound } from './audio';

export class DestructibleManager {
  public objects: DestructibleObject[] = [];

  constructor(objects: DestructibleObject[]) {
    this.objects = objects;
  }

  public setObjects(objects: DestructibleObject[]): void {
    this.objects = objects;
  }

  public update(dt: number): void {
    for (let i = 0; i < this.objects.length; i++) {
      const obj = this.objects[i];
      if (obj.active && obj.hitFlashTimer > 0) {
        obj.hitFlashTimer -= dt;
      }
    }
  }

  /**
   * Applies damage to a destructible object.
   * If destroyed, triggers debris particles and returns dropped loot (if any).
   */
  public damageObject(
    obj: DestructibleObject,
    damage: number,
    hitDir: Vector2,
    particleSystem: ParticleSystem
  ): PickupType | null {
    if (!obj.active) return null;

    obj.health -= damage;
    obj.hitFlashTimer = 0.08;

    // Small impact chips
    particleSystem.spawnDebris(obj.x, obj.y, obj.type, hitDir, 4);

    if (obj.health <= 0) {
      obj.active = false;

      // Play destruction audio
      if (obj.type === 'crate') {
        sound.playCrateBreak();
      } else if (obj.type === 'barrel') {
        sound.playBarrelBreak();
      } else {
        sound.playTrashBreak();
      }

      // Explosion of wooden splinters / barrel iron pieces / trash debris
      particleSystem.spawnDebris(obj.x, obj.y, obj.type, hitDir, 16);

      // Trigger Loot Drop Table: 40% Medkit, 40% Ammo, 20% Nothing
      const roll = Math.random();
      if (roll < 0.40) {
        return 'medkit';
      } else if (roll < 0.80) {
        return 'ammo';
      } else {
        return null; // 20% nothing
      }
    }

    return null;
  }

  public draw(ctx: CanvasRenderingContext2D): void {
    ctx.save();
    ctx.imageSmoothingEnabled = false;

    for (let i = 0; i < this.objects.length; i++) {
      const obj = this.objects[i];
      if (!obj.active) continue;

      const sprite = sprites.getSprite(`destructible_${obj.type}`);
      if (sprite) {
        ctx.save();
        ctx.translate(obj.x, obj.y);

        // Flash white if damaged
        if (obj.hitFlashTimer > 0) {
          ctx.filter = 'brightness(2.2)';
        }

        ctx.drawImage(sprite, -obj.w / 2, -obj.h / 2, obj.w, obj.h);
        ctx.restore();
      }
    }

    ctx.restore();
  }
}
