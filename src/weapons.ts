import type { WeaponConfig, WeaponType } from './types';
import { sound } from './audio';

export const WEAPON_CONFIGS: Record<WeaponType, WeaponConfig> = {
  pistol: {
    id: 'pistol',
    name: '9MM PISTOL',
    keyLabel: '1',
    fireRate: 0.25, // seconds
    damage: 36,
    pellets: 1,
    spread: 0.03,
    bulletSpeed: 960,
    bulletRadius: 3.5,
    bulletLifetime: 1.6,
    infiniteAmmo: true,
    maxAmmo: Infinity,
    recoil: 2.5,
  },
  shotgun: {
    id: 'shotgun',
    name: '12G SHOTGUN',
    keyLabel: '2',
    fireRate: 0.72,
    damage: 24,
    pellets: 6,
    spread: 0.32,
    bulletSpeed: 860,
    bulletRadius: 3.0,
    bulletLifetime: 0.75,
    infiniteAmmo: false,
    maxAmmo: 48,
    recoil: 8.0,
  },
  rifle: {
    id: 'rifle',
    name: 'ASSAULT RIFLE',
    keyLabel: '3',
    fireRate: 0.09,
    damage: 28,
    pellets: 1,
    spread: 0.08,
    bulletSpeed: 1050,
    bulletRadius: 3.2,
    bulletLifetime: 1.6,
    infiniteAmmo: false,
    maxAmmo: 180,
    recoil: 3.5,
  },
};

export class WeaponManager {
  public currentWeaponType: WeaponType = 'pistol';
  public ammo: Record<WeaponType, number> = {
    pistol: Infinity,
    shotgun: 24,
    rifle: 90,
  };

  private fireCooldown: number = 0;
  public isReloading: boolean = false;
  private reloadTimer: number = 0;

  public reset(): void {
    this.currentWeaponType = 'pistol';
    this.ammo = {
      pistol: Infinity,
      shotgun: 24,
      rifle: 90,
    };
    this.fireCooldown = 0;
    this.isReloading = false;
    this.reloadTimer = 0;
  }

  public getCurrentConfig(): WeaponConfig {
    return WEAPON_CONFIGS[this.currentWeaponType];
  }

  public getAmmoDisplay(): string {
    const config = this.getCurrentConfig();
    if (config.infiniteAmmo) {
      return '∞';
    }
    if (this.isReloading) {
      return 'RELOADING...';
    }
    return `${this.ammo[this.currentWeaponType]} / ${config.maxAmmo}`;
  }

  public getAmmoCount(): number {
    return this.ammo[this.currentWeaponType];
  }

  public update(dt: number): void {
    if (this.fireCooldown > 0) {
      this.fireCooldown -= dt;
    }

    if (this.isReloading) {
      this.reloadTimer -= dt;
      if (this.reloadTimer <= 0) {
        this.isReloading = false;
      }
    }
  }

  public reload(): boolean {
    if (this.isReloading) return false;
    const config = this.getCurrentConfig();
    if (config.infiniteAmmo) return false;
    if (this.ammo[this.currentWeaponType] >= config.maxAmmo) return false;

    this.isReloading = true;
    this.reloadTimer = 0.55;
    this.fireCooldown = 0.55;
    sound.playReload();
    return true;
  }

  public canShoot(): boolean {
    if (this.isReloading) return false;
    if (this.fireCooldown > 0) return false;
    const config = this.getCurrentConfig();
    if (!config.infiniteAmmo && this.ammo[this.currentWeaponType] <= 0) {
      return false;
    }
    return true;
  }

  public switchWeapon(type: WeaponType): boolean {
    if (this.currentWeaponType === type) return false;
    this.currentWeaponType = type;
    this.isReloading = false;
    this.fireCooldown = 0.12;
    sound.playWeaponSwitch();
    return true;
  }

  public switchNext(): void {
    const order: WeaponType[] = ['pistol', 'shotgun', 'rifle'];
    const idx = order.indexOf(this.currentWeaponType);
    this.switchWeapon(order[(idx + 1) % order.length]);
  }

  public switchPrev(): void {
    const order: WeaponType[] = ['pistol', 'shotgun', 'rifle'];
    const idx = order.indexOf(this.currentWeaponType);
    this.switchWeapon(order[(idx - 1 + order.length) % order.length]);
  }

  public consumeShot(): boolean {
    if (this.isReloading) return false;
    const config = this.getCurrentConfig();
    if (!config.infiniteAmmo) {
      if (this.ammo[this.currentWeaponType] <= 0) {
        sound.playDryFire();
        return false;
      }
      this.ammo[this.currentWeaponType]--;
    }

    this.fireCooldown = config.fireRate;

    // Play weapon specific audio
    if (config.id === 'shotgun') {
      sound.playShotgun();
    } else if (config.id === 'rifle') {
      sound.playRifle();
    } else {
      sound.playPistol();
    }

    return true;
  }

  public addAmmo(weapon: WeaponType, amount: number): number {
    if (weapon === 'pistol') return 0;
    const config = WEAPON_CONFIGS[weapon];
    const prev = this.ammo[weapon];
    this.ammo[weapon] = Math.min(config.maxAmmo, this.ammo[weapon] + amount);
    return this.ammo[weapon] - prev;
  }

  public addAmmoBoxes(): void {
    this.addAmmo('shotgun', 12);
    this.addAmmo('rifle', 45);
    sound.playReload();
  }
}
