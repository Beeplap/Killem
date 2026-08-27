export interface Vector2 {
  x: number;
  y: number;
}

export interface Bullet {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  damage: number;
  speed: number;
  lifetime: number;
  maxLifetime: number;
  active: boolean;
  color?: string;
}

export type ZombieType = 'regular' | 'dog' | 'heavy';

export interface Zombie {
  id: number;
  type: ZombieType;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  speed: number;
  health: number;
  maxHealth: number;
  damage: number;
  active: boolean;
  color: string;
  wobblePhase: number;
  wobbleSpeed: number;
  scoreValue: number;
  hitFlashTimer: number;
}

export type WeaponType = 'pistol' | 'shotgun' | 'rifle';

export interface WeaponConfig {
  id: WeaponType;
  name: string;
  keyLabel: string;
  fireRate: number;
  damage: number;
  pellets: number;
  spread: number;
  bulletSpeed: number;
  bulletRadius: number;
  bulletLifetime: number;
  infiniteAmmo: boolean;
  maxAmmo: number;
  recoil: number;
}

export type PickupType = 'ammo' | 'medkit';

export interface Pickup {
  id: number;
  type: PickupType;
  x: number;
  y: number;
  radius: number;
  active: boolean;
  lifetime: number;
  bobPhase: number;
}

export type DestructibleType = 'crate' | 'barrel' | 'trash';

export interface DestructibleObject {
  id: number;
  type: DestructibleType;
  x: number; // center x
  y: number; // center y
  w: number;
  h: number;
  health: number;
  maxHealth: number;
  hitFlashTimer: number;
  active: boolean;
}

export type WallType = 'wall' | 'fence' | 'pipe' | 'doorway';

export interface Wall {
  x: number;
  y: number;
  w: number;
  h: number;
  type: WallType;
}

export interface Room {
  id: string;
  name: string;
  x: number;
  y: number;
  w: number;
  h: number;
  isOutdoor: boolean;
  visited: boolean;
}

export interface Camera {
  x: number;
  y: number;
  viewportW: number;
  viewportH: number;
}

export interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  color: string;
  alpha: number;
  decay: number;
  active: boolean;
}

export interface TouchStickState {
  active: boolean;
  identifier: number | null;
  baseX: number;
  baseY: number;
  currentX: number;
  currentY: number;
  dx: number;
  dy: number;
  angle: number;
  intensity: number;
}
