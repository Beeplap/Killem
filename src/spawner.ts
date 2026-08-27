import { ZombieManager } from './zombie';
import type { ZombieType, Vector2, Room } from './types';
import { clamp } from './math';

export class Spawner {
  private zombieManager: ZombieManager;
  private spawnTimer: number = 0;
  private baseSpawnInterval: number = 1.4;
  private currentSpawnInterval: number = 1.4;
  public wave: number = 1;
  public elapsedTime: number = 0;

  constructor(zombieManager: ZombieManager) {
    this.zombieManager = zombieManager;
  }

  public reset(): void {
    this.spawnTimer = 0;
    this.currentSpawnInterval = this.baseSpawnInterval;
    this.wave = 1;
    this.elapsedTime = 0;
  }

  public update(
    dt: number,
    playerPos: Vector2,
    score: number,
    rooms: Room[],
    mapWidth: number,
    mapHeight: number
  ): void {
    this.elapsedTime += dt;
    this.spawnTimer += dt;

    this.wave = 1 + Math.floor(score / 800) + Math.floor(this.elapsedTime / 35);
    this.currentSpawnInterval = Math.max(0.35, this.baseSpawnInterval - (this.wave - 1) * 0.1);

    if (this.spawnTimer >= this.currentSpawnInterval) {
      this.spawnTimer = 0;

      let type: ZombieType = 'regular';
      const roll = Math.random();

      if (this.wave >= 3 && roll < 0.22) {
        type = 'heavy';
      } else if (roll < (this.wave >= 2 ? 0.44 : 0.28)) {
        type = 'dog';
      } else {
        type = 'regular';
      }

      // Spawn outside the player's immediate view, but within the world map
      const spawnPos = this.getSpawnPositionNearPlayer(playerPos, rooms, mapWidth, mapHeight);
      this.zombieManager.spawnZombie(type, spawnPos.x, spawnPos.y, this.wave);
    }
  }

  /**
   * Spawns an ambush horde when entering a new room
   */
  public triggerRoomAmbush(room: Room, wave: number): void {
    const count = 4 + Math.floor(Math.random() * 4) + wave;
    for (let i = 0; i < count; i++) {
      const type: ZombieType = i === 0 && wave >= 2 ? (Math.random() > 0.5 ? 'heavy' : 'dog') : (Math.random() > 0.6 ? 'dog' : 'regular');
      const sx = room.x + 60 + Math.random() * (room.w - 120);
      const sy = room.y + 60 + Math.random() * (room.h - 120);
      this.zombieManager.spawnZombie(type, sx, sy, wave);
    }
  }

  private getSpawnPositionNearPlayer(
    playerPos: Vector2,
    rooms: Room[],
    mapWidth: number,
    mapHeight: number
  ): Vector2 {
    // Pick an angle and distance (between 500px and 750px from player)
    const angle = Math.random() * Math.PI * 2;
    const dist = 520 + Math.random() * 250;

    let sx = playerPos.x + Math.cos(angle) * dist;
    let sy = playerPos.y + Math.sin(angle) * dist;

    sx = clamp(sx, 120, mapWidth - 120);
    sy = clamp(sy, 120, mapHeight - 120);

    return { x: sx, y: sy };
  }
}
