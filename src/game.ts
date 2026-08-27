import { Player } from './player';
import { BulletSystem } from './bullet';
import { ZombieManager } from './zombie';
import { Spawner } from './spawner';
import { ParticleSystem } from './particles';
import { VirtualJoystickManager } from './joystick';
import { WeaponManager } from './weapons';
import { PickupManager } from './pickups';
import { GameMap } from './map';
import { DestructibleManager } from './destructibles';
import { sound } from './audio';
import type { Vector2, WeaponType, WeaponConfig, Camera, PickupType } from './types';
import { checkAABBCollision, checkCircleCollision, circleToAABB, normalize, distanceSq, clamp } from './math';

export interface GameUIState {
  score: number;
  kills: number;
  health: number;
  maxHealth: number;
  wave: number;
  isGameOver: boolean;
  currentWeapon: WeaponConfig;
  currentWeaponType: WeaponType;
  ammoDisplay: string;
  ammoCount: number;
  shotgunAmmo: number;
  rifleAmmo: number;
  roomName: string;
  roomAnnouncement: string;
}

export class Game {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;

  private player: Player;
  private bulletSystem: BulletSystem;
  private zombieManager: ZombieManager;
  private spawner: Spawner;
  private particleSystem: ParticleSystem;
  private joystickManager: VirtualJoystickManager;
  public weaponManager: WeaponManager;
  private pickupManager: PickupManager;
  public map: GameMap;
  public destructibleManager: DestructibleManager;

  // Camera & Viewport
  public camera: Camera = { x: 0, y: 0, viewportW: 0, viewportH: 0 };
  private width: number = 0;
  private height: number = 0;
  private dpr: number = 1;

  // Controls & input
  private keys: Record<string, boolean> = {};
  private screenMousePos: Vector2 = { x: 0, y: 0 };
  private worldMousePos: Vector2 = { x: 0, y: 0 };
  private isMouseDown: boolean = false;

  // Game state
  public isRunning: boolean = false;
  public isGameOver: boolean = false;
  public score: number = 0;
  public kills: number = 0;
  public highScore: number = 0;

  // Exploration & Room Announcement
  public roomAnnouncement: string = '';
  private announcementTimer: number = 0;

  // Screen shake & damage vignette
  private screenShake: number = 0;
  private damageFlash: number = 0;
  private groanTimer: number = 0;

  // Loop timing
  private lastTime: number = 0;
  private animationFrameId: number = 0;

  private onStateChange?: (state: GameUIState) => void;

  constructor(canvas: HTMLCanvasElement, onStateChange?: typeof Game.prototype.onStateChange) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d', { alpha: false })!;
    this.onStateChange = onStateChange;

    this.map = new GameMap();
    this.player = new Player(450, 1250); // Start at Control Airlock Hub
    this.bulletSystem = new BulletSystem(450);
    this.zombieManager = new ZombieManager();
    this.spawner = new Spawner(this.zombieManager);
    this.particleSystem = new ParticleSystem(550);
    this.particleSystem.initDecals(this.map.width, this.map.height);
    this.joystickManager = new VirtualJoystickManager(canvas);
    this.weaponManager = new WeaponManager();
    this.pickupManager = new PickupManager();
    this.destructibleManager = new DestructibleManager(this.map.destructibles);

    // Exploration listener
    this.map.onRoomEnter = (room) => {
      this.roomAnnouncement = room.name;
      this.announcementTimer = 3.5;
      this.spawner.triggerRoomAmbush(room, this.spawner.wave);
    };

    this.loadHighScore();
    this.setupListeners();
    this.resize();
  }

  private loadHighScore(): void {
    const saved = localStorage.getItem('zombie_shooter_highscore');
    if (saved) {
      this.highScore = parseInt(saved, 10) || 0;
    }
  }

  private saveHighScore(): void {
    if (this.score > this.highScore) {
      this.highScore = this.score;
      localStorage.setItem('zombie_shooter_highscore', this.highScore.toString());
    }
  }

  public resize(): void {
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.width = window.innerWidth;
    this.height = window.innerHeight;

    this.camera.viewportW = this.width;
    this.camera.viewportH = this.height;

    this.canvas.width = Math.floor(this.width * this.dpr);
    this.canvas.height = Math.floor(this.height * this.dpr);
    this.canvas.style.width = `${this.width}px`;
    this.canvas.style.height = `${this.height}px`;

    this.ctx.resetTransform();
    this.ctx.scale(this.dpr, this.dpr);
    this.ctx.imageSmoothingEnabled = false;

    this.updateCamera();
  }

  private updateCamera(): void {
    // Smooth camera centered on player clamped to map borders
    const targetX = this.player.x - this.width / 2;
    const targetY = this.player.y - this.height / 2;

    this.camera.x = clamp(targetX, 0, Math.max(0, this.map.width - this.width));
    this.camera.y = clamp(targetY, 0, Math.max(0, this.map.height - this.height));

    this.worldMousePos.x = this.screenMousePos.x + this.camera.x;
    this.worldMousePos.y = this.screenMousePos.y + this.camera.y;
  }

  private setupListeners(): void {
    window.addEventListener('resize', () => this.resize());

    window.addEventListener('keydown', (e) => {
      this.keys[e.code] = true;

      // Weapon switching (1, 2, 3)
      if (e.code === 'Digit1' || e.code === 'Numpad1') {
        this.switchWeapon('pistol');
      } else if (e.code === 'Digit2' || e.code === 'Numpad2') {
        this.switchWeapon('shotgun');
      } else if (e.code === 'Digit3' || e.code === 'Numpad3') {
        this.switchWeapon('rifle');
      }

      if (e.code === 'KeyR') {
        if (this.isGameOver) {
          this.restart();
        } else {
          this.weaponManager.reload();
          this.notifyUI();
        }
      }
    });

    window.addEventListener('keyup', (e) => {
      this.keys[e.code] = false;
    });

    window.addEventListener('mousemove', (e) => {
      this.screenMousePos.x = e.clientX;
      this.screenMousePos.y = e.clientY;
      this.worldMousePos.x = e.clientX + this.camera.x;
      this.worldMousePos.y = e.clientY + this.camera.y;
    });

    this.canvas.addEventListener('mousedown', (e) => {
      if (e.button === 0) {
        this.isMouseDown = true;
        this.screenMousePos.x = e.clientX;
        this.screenMousePos.y = e.clientY;
        this.worldMousePos.x = e.clientX + this.camera.x;
        this.worldMousePos.y = e.clientY + this.camera.y;
      }
    });

    window.addEventListener('mouseup', (e) => {
      if (e.button === 0) {
        this.isMouseDown = false;
      }
    });

    window.addEventListener('wheel', (e) => {
      if (e.deltaY > 0) {
        this.weaponManager.switchNext();
      } else if (e.deltaY < 0) {
        this.weaponManager.switchPrev();
      }
      this.notifyUI();
    });

    this.canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  public switchWeapon(type: WeaponType): void {
    if (this.weaponManager.switchWeapon(type)) {
      this.notifyUI();
    }
  }

  public start(): void {
    this.isRunning = true;
    this.isGameOver = false;
    this.score = 0;
    this.kills = 0;
    this.groanTimer = 2;
    this.roomAnnouncement = 'CONTROL AIRLOCK // SECTOR 1';
    this.announcementTimer = 3.5;

    this.map.reset();
    this.destructibleManager.setObjects(this.map.destructibles);
    this.player.reset(450, 1250);
    this.bulletSystem.reset();
    this.zombieManager.reset();
    this.spawner.reset();
    this.particleSystem.reset();
    this.particleSystem.initDecals(this.map.width, this.map.height);
    this.weaponManager.reset();
    this.pickupManager.reset();

    this.lastTime = performance.now();
    cancelAnimationFrame(this.animationFrameId);
    this.loop = this.loop.bind(this);
    this.animationFrameId = requestAnimationFrame(this.loop);

    this.notifyUI();
  }

  public restart(): void {
    this.start();
  }

  private loop(currentTime: number): void {
    if (!this.isRunning) return;

    let dt = (currentTime - this.lastTime) / 1000;
    this.lastTime = currentTime;

    if (dt > 0.1) dt = 0.1;

    this.update(dt);
    this.render();

    this.animationFrameId = requestAnimationFrame(this.loop);
  }

  private update(dt: number): void {
    if (this.isGameOver) return;

    // 1. Movement Input
    let moveX = 0;
    let moveY = 0;

    if (this.keys['KeyW'] || this.keys['ArrowUp']) moveY -= 1;
    if (this.keys['KeyS'] || this.keys['ArrowDown']) moveY += 1;
    if (this.keys['KeyA'] || this.keys['ArrowLeft']) moveX -= 1;
    if (this.keys['KeyD'] || this.keys['ArrowRight']) moveX += 1;

    const touchMove = this.joystickManager.getMoveVector();
    if (touchMove.x !== 0 || touchMove.y !== 0) {
      moveX = touchMove.x;
      moveY = touchMove.y;
    }

    // 2. Aim Input
    const touchAim = this.joystickManager.isAimingOrShooting();
    let aimWorldPos: Vector2 | null = this.worldMousePos;
    let aimAngle: number | null = null;
    let isShooting = this.isMouseDown;

    if (touchAim.shooting && touchAim.angle !== null) {
      aimAngle = touchAim.angle;
      aimWorldPos = null;
      isShooting = true;
    }

    // 3. Update Player & Resolve Solid Wall Collisions
    this.player.update(dt, { x: moveX, y: moveY }, aimWorldPos, aimAngle, this.map.width, this.map.height);
    const resolvedPlayerPos = this.map.resolveWallCollision({ x: this.player.x, y: this.player.y }, this.player.radius);
    this.player.x = resolvedPlayerPos.x;
    this.player.y = resolvedPlayerPos.y;

    // Solid collision against intact crates/barrels
    this.resolvePlayerDestructibleCollisions();

    // 4. Update Camera & Room Exploration
    this.updateCamera();
    this.map.updatePlayerRoom({ x: this.player.x, y: this.player.y });

    if (this.announcementTimer > 0) {
      this.announcementTimer -= dt;
      if (this.announcementTimer <= 0) {
        this.roomAnnouncement = '';
      }
    }

    // 5. Update Weapon & Shooting
    this.weaponManager.update(dt);

    if (isShooting) {
      const weapon = this.weaponManager.getCurrentConfig();
      if (this.weaponManager.canShoot()) {
        const muzzle = this.player.getMuzzlePosition(weapon.id);
        let target: Vector2;

        if (aimAngle !== null) {
          target = {
            x: muzzle.x + Math.cos(aimAngle) * 500,
            y: muzzle.y + Math.sin(aimAngle) * 500,
          };
        } else {
          target = this.worldMousePos;
        }

        if (this.weaponManager.consumeShot()) {
          const firedBullets = this.bulletSystem.shootWeapon(muzzle, target, weapon);
          if (firedBullets.length > 0) {
            const first = firedBullets[0];
            const dir = normalize(first.vx, first.vy);
            this.particleSystem.spawnMuzzleSparks(muzzle.x, muzzle.y, dir.x, dir.y);
            this.screenShake = Math.max(this.screenShake, weapon.recoil);
          }
        }
      }
    }

    this.bulletSystem.update(dt, this.map.width, this.map.height);

    // 6. Update Pickups & Auto-Collect
    this.pickupManager.update(
      dt,
      { x: this.player.x, y: this.player.y },
      this.player.radius,
      (type: PickupType) => {
        if (type === 'ammo') {
          this.weaponManager.addAmmoBoxes();
        } else if (type === 'medkit') {
          this.player.heal(35);
        }
        this.notifyUI();
      }
    );

    // 7. Update Destructibles
    this.destructibleManager.update(dt);

    // 8. Update Spawner & Zombies
    this.spawner.update(dt, { x: this.player.x, y: this.player.y }, this.score, this.map.rooms, this.map.width, this.map.height);
    this.zombieManager.update(dt, { x: this.player.x, y: this.player.y });

    // Resolve wall collision for zombies
    for (const z of this.zombieManager.zombies) {
      if (z.active) {
        const res = this.map.resolveWallCollision({ x: z.x, y: z.y }, z.radius);
        z.x = res.x;
        z.y = res.y;
      }
    }

    // Periodic eerie zombie groans
    this.groanTimer -= dt;
    if (this.groanTimer <= 0) {
      this.groanTimer = 4 + Math.random() * 4;
      const zombies = this.zombieManager.zombies;
      let closeCount = 0;
      for (let i = 0; i < zombies.length; i++) {
        if (zombies[i].active && distanceSq(zombies[i].x, zombies[i].y, this.player.x, this.player.y) < 420 * 420) {
          closeCount++;
        }
      }
      if (closeCount > 0) {
        sound.playZombieGroan();
      }
    }

    // 9. Handle All Collisions (Bullets vs Zombies, Bullets vs Destructibles, Bullets vs Walls, Zombies vs Player)
    this.checkCollisions();

    // 10. Update Particles & Screen FX
    this.particleSystem.update(dt);

    if (this.screenShake > 0) {
      this.screenShake -= dt * 22;
      if (this.screenShake < 0) this.screenShake = 0;
    }

    if (this.damageFlash > 0) {
      this.damageFlash -= dt * 3.2;
      if (this.damageFlash < 0) this.damageFlash = 0;
    }

    this.notifyUI();
  }

  private resolvePlayerDestructibleCollisions(): void {
    const px = this.player.x;
    const py = this.player.y;
    const pr = this.player.radius;

    for (const obj of this.destructibleManager.objects) {
      if (!obj.active) continue;

      const halfW = obj.w / 2;
      const halfH = obj.h / 2;
      const closestX = Math.max(obj.x - halfW, Math.min(px, obj.x + halfW));
      const closestY = Math.max(obj.y - halfH, Math.min(py, obj.y + halfH));

      const dx = px - closestX;
      const dy = py - closestY;
      const d2 = dx * dx + dy * dy;

      if (d2 < pr * pr && d2 > 0.0001) {
        const d = Math.sqrt(d2);
        const overlap = pr - d;
        this.player.x += (dx / d) * overlap;
        this.player.y += (dy / d) * overlap;
      }
    }
  }

  private checkCollisions(): void {
    const playerBox = circleToAABB(this.player.x, this.player.y, this.player.radius);
    const zombies = this.zombieManager.zombies;
    const destructibles = this.destructibleManager.objects;

    // Bullet Checks
    this.bulletSystem.pool.forEachActive((bullet) => {
      // 1. Bullet vs Solid Walls
      if (this.map.checkBulletWallCollision(bullet.x, bullet.y)) {
        this.bulletSystem.pool.release(bullet);
        const bDir = normalize(bullet.vx, bullet.vy);
        this.particleSystem.spawnMuzzleSparks(bullet.x, bullet.y, -bDir.x, -bDir.y);
        return;
      }

      const bulletBox = circleToAABB(bullet.x, bullet.y, bullet.radius);

      // 2. Bullet vs Destructible Objects (Wooden Crates, Barrels, Trash Bags)
      for (let i = 0; i < destructibles.length; i++) {
        const obj = destructibles[i];
        if (!obj.active) continue;

        const objBox = {
          minX: obj.x - obj.w / 2,
          minY: obj.y - obj.h / 2,
          maxX: obj.x + obj.w / 2,
          maxY: obj.y + obj.h / 2,
        };

        if (checkAABBCollision(bulletBox, objBox)) {
          this.bulletSystem.pool.release(bullet);
          const bDir = normalize(bullet.vx, bullet.vy);
          const loot = this.destructibleManager.damageObject(obj, bullet.damage, bDir, this.particleSystem);

          if (loot) {
            // Drop Health Pack (40%) or Ammo (40%)
            this.pickupManager.pickups.push({
              id: Math.floor(Math.random() * 100000),
              type: loot,
              x: obj.x,
              y: obj.y,
              radius: 14,
              active: true,
              lifetime: 25,
              bobPhase: 0,
            });
          }
          return;
        }
      }

      // 3. Bullet vs Zombies
      for (let i = 0; i < zombies.length; i++) {
        const zombie = zombies[i];
        if (!zombie.active) continue;

        const zombieBox = circleToAABB(zombie.x, zombie.y, zombie.radius);
        if (!checkAABBCollision(bulletBox, zombieBox)) continue;

        if (checkCircleCollision(bullet.x, bullet.y, bullet.radius, zombie.x, zombie.y, zombie.radius)) {
          this.bulletSystem.pool.release(bullet);
          zombie.health -= bullet.damage;
          zombie.hitFlashTimer = 0.08;

          const bDir = normalize(bullet.vx, bullet.vy);
          this.particleSystem.spawnBlood(bullet.x, bullet.y, bDir.x, bDir.y, 6);

          const knockback = zombie.type === 'heavy' ? 2 : (zombie.type === 'dog' ? 8 : 5);
          zombie.x += bDir.x * knockback;
          zombie.y += bDir.y * knockback;

          if (zombie.health <= 0) {
            zombie.active = false;
            this.kills++;
            this.score += zombie.scoreValue;
            this.saveHighScore();

            if (zombie.type === 'dog') {
              sound.playDogYelp();
            } else {
              sound.playZombieKill();
            }

            // Persistent blood splatters baked onto map floor tiles
            this.particleSystem.spawnDeathBlood(zombie.x, zombie.y, bDir.x, bDir.y, zombie.type);
            this.pickupManager.maybeSpawnPickup(zombie.x, zombie.y, zombie.type === 'heavy');
          } else {
            if (zombie.type === 'heavy') sound.playHeavyHit();
            else sound.playZombieHit();
          }

          break;
        }
      }
    });

    // Zombie vs Player Collisions
    for (let i = 0; i < zombies.length; i++) {
      const zombie = zombies[i];
      if (!zombie.active) continue;

      const zombieBox = circleToAABB(zombie.x, zombie.y, zombie.radius);

      if (checkAABBCollision(playerBox, zombieBox)) {
        if (checkCircleCollision(this.player.x, this.player.y, this.player.radius, zombie.x, zombie.y, zombie.radius)) {
          const pushDir = normalize(this.player.x - zombie.x, this.player.y - zombie.y);
          const wasDamaged = this.player.takeDamage(zombie.damage, pushDir);

          if (wasDamaged) {
            sound.playPlayerHurt();
            this.screenShake = zombie.type === 'heavy' ? 18 : 10;
            this.damageFlash = 0.55;

            if (this.player.isDead) {
              this.handleGameOver();
              break;
            }
          }
        }
      }
    }
  }

  private handleGameOver(): void {
    this.isGameOver = true;
    this.saveHighScore();
    sound.playGameOver();
    this.notifyUI();
  }

  /**
   * Fully Lit & Bright 2D Rendering.
   * Completely removed dark cones and fog of war.
   */
  private render(): void {
    const ctx = this.ctx;

    // Reset transform & apply Screen Shake
    ctx.save();
    ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);

    if (this.screenShake > 0) {
      const shakeX = (Math.random() - 0.5) * this.screenShake * 1.6;
      const shakeY = (Math.random() - 0.5) * this.screenShake * 1.6;
      ctx.translate(shakeX, shakeY);
    }

    // World Space Translation (Camera follows Player)
    ctx.save();
    ctx.translate(-this.camera.x, -this.camera.y);

    // 1. Fully-Lit Concrete Map Floor Tiles & Walls
    this.map.drawFloor(ctx);

    // 2. Persistent Floor Blood Decals
    this.particleSystem.drawDecals(ctx);

    // 3. Destructible Environmental Objects (Pixel Wooden Crates, Barrels, Trash Bags)
    this.destructibleManager.draw(ctx);

    // 4. Collectible Pickups (Health Packs & Ammo Crates)
    this.pickupManager.draw(ctx);

    // 5. Pixel Art Zombies & Infected Dogs
    this.zombieManager.draw(ctx, { x: this.player.x, y: this.player.y });

    // 6. Pixel Art Commando Player
    this.player.draw(ctx, this.weaponManager.currentWeaponType);

    // 7. High-Speed Bullets & Tracers
    this.bulletSystem.draw(ctx);

    // 8. Dynamic Debris & Blood Splatter Particles
    this.particleSystem.drawParticles(ctx);

    ctx.restore(); // Restore world translation

    // ----------------------------------------------------
    // Screen-Space HUD & UI Overlays
    // ----------------------------------------------------

    // Damage Red Flash
    if (this.damageFlash > 0) {
      ctx.fillStyle = `rgba(220, 38, 38, ${Math.min(0.55, this.damageFlash)})`;
      ctx.fillRect(0, 0, this.width, this.height);
    }

    // Room Announcement Banner
    if (this.announcementTimer > 0 && this.roomAnnouncement) {
      this.drawRoomBanner(ctx);
    }

    // Minimap Radar Overview
    this.drawMinimap(ctx);

    // Virtual Joysticks
    this.joystickManager.draw(ctx, this.width, this.height);

    ctx.restore();
  }

  private drawRoomBanner(ctx: CanvasRenderingContext2D): void {
    ctx.save();
    const alpha = Math.min(1, this.announcementTimer);
    ctx.globalAlpha = alpha;

    const bannerY = 22;
    const bannerW = 440;
    const bannerH = 34;
    const bannerX = this.width / 2 - bannerW / 2;

    // Dark steel plate with blood-red hazard border
    ctx.fillStyle = 'rgba(17, 19, 24, 0.92)';
    ctx.strokeStyle = '#dc2626';
    ctx.lineWidth = 2;

    ctx.beginPath();
    ctx.rect(bannerX, bannerY, bannerW, bannerH);
    ctx.fill();
    ctx.stroke();

    // Corner rivets
    ctx.fillStyle = '#64748b';
    ctx.fillRect(bannerX + 3, bannerY + 3, 3, 3);
    ctx.fillRect(bannerX + bannerW - 6, bannerY + 3, 3, 3);
    ctx.fillRect(bannerX + 3, bannerY + bannerH - 6, 3, 3);
    ctx.fillRect(bannerX + bannerW - 6, bannerY + bannerH - 6, 3, 3);

    ctx.font = '900 13px "Courier New", Courier, monospace';
    ctx.fillStyle = '#facc15';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`SECTOR: ${this.roomAnnouncement}`, this.width / 2, bannerY + bannerH / 2);

    ctx.restore();
  }

  /**
   * Classic Circular / Grunge Radar Minimap in Top-Right Corner
   */
  private drawMinimap(ctx: CanvasRenderingContext2D): void {
    const cx = this.width - 76;
    const cy = 76;
    const rad = 50;

    ctx.save();

    // 1. Heavy metallic outer rim with inset bevel
    ctx.beginPath();
    ctx.arc(cx, cy, rad + 6, 0, Math.PI * 2);
    ctx.fillStyle = '#1e2129';
    ctx.fill();
    ctx.strokeStyle = '#3e4250';
    ctx.lineWidth = 2.5;
    ctx.stroke();

    // 2. Metallic perimeter bolts/rivets
    ctx.fillStyle = '#64748b';
    for (let i = 0; i < 8; i++) {
      const boltAngle = (i / 8) * Math.PI * 2;
      const bx = cx + Math.cos(boltAngle) * (rad + 3);
      const by = cy + Math.sin(boltAngle) * (rad + 3);
      ctx.fillRect(bx - 1.5, by - 1.5, 3, 3);
    }

    // 3. Dark CRT radar screen (clipped to circle)
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, rad, 0, Math.PI * 2);
    ctx.clip();

    ctx.fillStyle = '#0b0d12';
    ctx.fillRect(cx - rad, cy - rad, rad * 2, rad * 2);

    // Range rings & crosshairs
    ctx.strokeStyle = 'rgba(71, 85, 105, 0.4)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(cx, cy, rad * 0.5, 0, Math.PI * 2);
    ctx.arc(cx, cy, rad * 0.85, 0, Math.PI * 2);
    ctx.moveTo(cx - rad, cy);
    ctx.lineTo(cx + rad, cy);
    ctx.moveTo(cx, cy - rad);
    ctx.lineTo(cx, cy + rad);
    ctx.stroke();

    // Map scaling
    const mw = rad * 1.7;
    const mh = rad * 1.7;
    const mx = cx - mw / 2;
    const my = cy - mh / 2;
    const scaleX = mw / this.map.width;
    const scaleY = mh / this.map.height;

    // Draw explored rooms
    for (const r of this.map.rooms) {
      const rx = mx + r.x * scaleX;
      const ry = my + r.y * scaleY;
      const rw = r.w * scaleX;
      const rh = r.h * scaleY;

      if (r.visited) {
        ctx.fillStyle = r.isOutdoor ? 'rgba(56, 189, 248, 0.22)' : 'rgba(100, 116, 139, 0.35)';
        ctx.fillRect(rx, ry, rw, rh);
      }
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
      ctx.strokeRect(rx, ry, rw, rh);
    }

    // Destructible crates as small yellow dots
    ctx.fillStyle = '#eab308';
    for (const d of this.destructibleManager.objects) {
      if (d.active) {
        ctx.fillRect(mx + d.x * scaleX - 1, my + d.y * scaleY - 1, 2, 2);
      }
    }

    // Zombie red pings
    ctx.fillStyle = '#ef4444';
    for (const z of this.zombieManager.zombies) {
      if (z.active) {
        ctx.fillRect(mx + z.x * scaleX - 1, my + z.y * scaleY - 1, 2, 2);
      }
    }

    // Player bright green blip with crosshair
    const px = mx + this.player.x * scaleX;
    const py = my + this.player.y * scaleY;
    ctx.fillStyle = '#22c55e';
    ctx.beginPath();
    ctx.arc(px, py, 2.5, 0, Math.PI * 2);
    ctx.fill();

    // Subtle sweeping radar line
    const sweepAngle = (performance.now() * 0.0018) % (Math.PI * 2);
    ctx.strokeStyle = 'rgba(34, 197, 94, 0.28)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(sweepAngle) * rad, cy + Math.sin(sweepAngle) * rad);
    ctx.stroke();

    ctx.restore(); // end clip

    // Inner dark rim ring
    ctx.beginPath();
    ctx.arc(cx, cy, rad, 0, Math.PI * 2);
    ctx.strokeStyle = '#2d313d';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.restore();
  }

  private notifyUI(): void {
    if (this.onStateChange) {
      this.onStateChange({
        score: this.score,
        kills: this.kills,
        health: this.player.health,
        maxHealth: this.player.maxHealth,
        wave: this.spawner.wave,
        isGameOver: this.isGameOver,
        currentWeapon: this.weaponManager.getCurrentConfig(),
        currentWeaponType: this.weaponManager.currentWeaponType,
        ammoDisplay: this.weaponManager.getAmmoDisplay(),
        ammoCount: this.weaponManager.getAmmoCount(),
        shotgunAmmo: this.weaponManager.ammo.shotgun,
        rifleAmmo: this.weaponManager.ammo.rifle,
        roomName: this.map.currentRoom ? this.map.currentRoom.name : 'SECTOR 1',
        roomAnnouncement: this.roomAnnouncement,
      });
    }
  }

  public getPlayer(): Player {
    return this.player;
  }
}
