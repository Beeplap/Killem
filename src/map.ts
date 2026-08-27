import type { Wall, Room, DestructibleObject, DestructibleType, Vector2 } from './types';

export class GameMap {
  public readonly width: number = 3200;
  public readonly height: number = 2400;

  public rooms: Room[] = [];
  public walls: Wall[] = [];
  public destructibles: DestructibleObject[] = [];
  private nextDestructibleId: number = 1;

  public currentRoom: Room | null = null;
  public onRoomEnter?: (room: Room) => void;

  private floorCanvas: HTMLCanvasElement;
  private floorCtx: CanvasRenderingContext2D;

  constructor() {
    this.floorCanvas = document.createElement('canvas');
    this.floorCanvas.width = this.width;
    this.floorCanvas.height = this.height;
    this.floorCtx = this.floorCanvas.getContext('2d')!;

    this.buildMapLayout();
    this.bakeFloor();
  }

  /**
   * Builds the connected multi-room industrial compound inspired by Zombie Shooter / Alien Shooter
   */
  private buildMapLayout(): void {
    // 1. Define Connected Rooms
    this.rooms = [
      {
        id: 'spawn_hub',
        name: 'CONTROL AIRLOCK // SECTOR 1',
        x: 100,
        y: 950,
        w: 700,
        h: 650,
        isOutdoor: false,
        visited: true,
      },
      {
        id: 'generator_room',
        name: 'AUXILIARY GENERATOR SECTOR',
        x: 100,
        y: 200,
        w: 700,
        h: 650,
        isOutdoor: false,
        visited: false,
      },
      {
        id: 'central_hall',
        name: 'MAIN ARTERY CORRIDOR',
        x: 900,
        y: 200,
        w: 450,
        h: 1700,
        isOutdoor: false,
        visited: false,
      },
      {
        id: 'bio_lab',
        name: 'BIO-RESEARCH LABORATORY',
        x: 1450,
        y: 200,
        w: 850,
        h: 700,
        isOutdoor: false,
        visited: false,
      },
      {
        id: 'outdoor_yard',
        name: 'INDUSTRIAL OUTDOOR COURTYARD',
        x: 1450,
        y: 1000,
        w: 1050,
        h: 1100,
        isOutdoor: true, // Rainy outdoor industrial yard from reference image
        visited: false,
      },
      {
        id: 'deep_storage',
        name: 'CARGO SHIPPING BAY & DEPOT',
        x: 2600,
        y: 400,
        w: 500,
        h: 1700,
        isOutdoor: false,
        visited: false,
      },
    ];

    // 2. Build Walls & Fences with Doorways
    const wallThick = 28;

    // Perimeter boundary walls
    this.walls.push(
      { x: 0, y: 0, w: this.width, h: wallThick, type: 'wall' }, // Top
      { x: 0, y: this.height - wallThick, w: this.width, h: wallThick, type: 'wall' }, // Bottom
      { x: 0, y: 0, w: wallThick, h: this.height, type: 'wall' }, // Left
      { x: this.width - wallThick, y: 0, w: wallThick, h: this.height, type: 'wall' } // Right
    );

    // Wall between Spawn Hub & Generator Room (with Doorway at x: 400-540)
    this.walls.push(
      { x: 100, y: 850, w: 300, h: wallThick, type: 'wall' },
      { x: 540, y: 850, w: 260, h: wallThick, type: 'wall' }
    );

    // Wall between Spawn/Gen and Central Hall (x: 800) with 2 Doorways
    this.walls.push(
      { x: 800, y: 200, w: wallThick, h: 320, type: 'wall' },
      // Doorway 1 at y: 520 - 660 (Generator to Central Hall)
      { x: 800, y: 660, w: wallThick, h: 540, type: 'wall' },
      // Doorway 2 at y: 1200 - 1340 (Spawn Hub to Central Hall)
      { x: 800, y: 1340, w: wallThick, h: 560, type: 'wall' }
    );

    // Wall between Central Hall & Bio Lab / Outdoor Yard (x: 1350)
    this.walls.push(
      { x: 1350, y: 200, w: wallThick, h: 320, type: 'wall' },
      // Doorway at y: 520 - 660 (Central Hall to Bio Lab)
      { x: 1350, y: 660, w: wallThick, h: 580, type: 'wall' },
      // Doorway at y: 1240 - 1380 (Central Hall to Outdoor Yard)
      { x: 1350, y: 1380, w: wallThick, h: 520, type: 'wall' }
    );

    // Dividing wall between Bio Lab and Outdoor Yard (y: 900)
    this.walls.push(
      { x: 1350, y: 900, w: 380, h: wallThick, type: 'wall' },
      // Doorway at x: 1730 - 1870
      { x: 1870, y: 900, w: 530, h: wallThick, type: 'wall' }
    );

    // Chain-link fences in the Outdoor Courtyard (inspired by reference image top-left)
    this.walls.push(
      { x: 1700, y: 1250, w: 16, h: 420, type: 'fence' },
      { x: 1700, y: 1670, w: 320, h: 16, type: 'fence' },
      { x: 2150, y: 1250, w: 16, h: 520, type: 'fence' }
    );

    // Wall between Outdoor Yard and Deep Storage (x: 2500)
    this.walls.push(
      { x: 2500, y: 400, w: wallThick, h: 500, type: 'wall' },
      // Big warehouse door at y: 900 - 1100
      { x: 2500, y: 1100, w: wallThick, h: 500, type: 'wall' },
      // Second cargo door at y: 1600 - 1760
      { x: 2500, y: 1760, w: wallThick, h: 340, type: 'wall' }
    );

    // 3. Populate Destructible Objects across all rooms
    this.populateDestructibles();
  }

  /**
   * Spawns Wooden Crates, Barrels, and Trash Bags throughout rooms
   */
  private populateDestructibles(): void {
    const addObj = (type: DestructibleType, x: number, y: number) => {
      let w = 32;
      let h = 32;
      let health = 30;

      if (type === 'barrel') {
        w = 28;
        h = 28;
        health = 25;
      } else if (type === 'trash') {
        w = 26;
        h = 24;
        health = 18;
      }

      this.destructibles.push({
        id: this.nextDestructibleId++,
        type,
        x,
        y,
        w,
        h,
        health,
        maxHealth: health,
        hitFlashTimer: 0,
        active: true,
      });
    };

    // Zone 1: Spawn Hub
    addObj('crate', 220, 1050);
    addObj('crate', 255, 1050);
    addObj('crate', 220, 1085);
    addObj('barrel', 680, 1050);
    addObj('barrel', 680, 1085);
    addObj('trash', 200, 1480);
    addObj('trash', 230, 1490);
    addObj('trash', 720, 1480);

    // Zone 2: Generator Sector
    addObj('barrel', 200, 300);
    addObj('barrel', 235, 300);
    addObj('barrel', 200, 335);
    addObj('barrel', 235, 335);
    addObj('crate', 650, 300);
    addObj('crate', 685, 300);
    addObj('trash', 650, 720);
    addObj('barrel', 450, 450);

    // Zone 3: Central Hallway
    addObj('trash', 950, 350);
    addObj('trash', 980, 360);
    addObj('crate', 1250, 500);
    addObj('crate', 1250, 535);
    addObj('barrel', 950, 1100);
    addObj('crate', 950, 1135);
    addObj('trash', 1250, 1600);
    addObj('trash', 1280, 1610);

    // Zone 4: Bio-Research Lab
    addObj('crate', 1520, 300);
    addObj('crate', 1555, 300);
    addObj('crate', 1520, 335);
    addObj('trash', 2150, 300);
    addObj('trash', 2180, 310);
    addObj('crate', 1850, 550);
    addObj('barrel', 2150, 780);
    addObj('trash', 1550, 780);

    // Zone 5: Outdoor Courtyard (stacks like the reference screenshot!)
    addObj('crate', 1550, 1100);
    addObj('crate', 1585, 1100);
    addObj('crate', 1620, 1100);
    addObj('crate', 1550, 1135);
    addObj('crate', 1585, 1135);
    addObj('barrel', 1800, 1300);
    addObj('barrel', 1835, 1300);
    addObj('barrel', 1870, 1300);
    addObj('barrel', 1800, 1335);
    addObj('trash', 1500, 1950);
    addObj('trash', 1530, 1960);
    addObj('crate', 2250, 1400);
    addObj('crate', 2285, 1400);
    addObj('crate', 2250, 1435);
    addObj('barrel', 2300, 1850);
    addObj('barrel', 2335, 1850);

    // Zone 6: Deep Storage Depot
    addObj('crate', 2700, 500);
    addObj('crate', 2735, 500);
    addObj('crate', 2770, 500);
    addObj('crate', 2805, 500);
    addObj('crate', 2700, 535);
    addObj('crate', 2735, 535);
    addObj('barrel', 2950, 800);
    addObj('barrel', 2950, 835);
    addObj('trash', 2680, 1250);
    addObj('trash', 2710, 1260);
    addObj('crate', 2800, 1500);
    addObj('crate', 2835, 1500);
    addObj('barrel', 2750, 1800);
    addObj('barrel', 2785, 1800);
    addObj('trash', 2950, 1950);
  }

  /**
   * Bakes fully-lit, crisp pixel-art floor tiles, concrete corridors,
   * wet outdoor asphalt, and wall shadows across the entire 3200x2400 map.
   */
  private bakeFloor(): void {
    const ctx = this.floorCtx;
    ctx.imageSmoothingEnabled = false;

    // 1. Base dark background
    ctx.fillStyle = '#090d16';
    ctx.fillRect(0, 0, this.width, this.height);

    // 2. Render Room Floors
    for (const room of this.rooms) {
      if (room.isOutdoor) {
        // Outdoor Yard: Wet asphalt with puddles and foliage edges (from reference image)
        this.renderOutdoorFloor(ctx, room);
      } else {
        // Indoor Industrial Corridors & Tiled Lab Rooms
        this.renderIndoorFloor(ctx, room);
      }
    }

    // 3. Render Walls & Fences onto the map floor
    this.renderWallArtwork(ctx);
  }

  private renderIndoorFloor(ctx: CanvasRenderingContext2D, room: Room): void {
    const tileSize = 48;
    const isLab = room.id === 'bio_lab';
    const isHub = room.id === 'spawn_hub';

    for (let x = room.x; x < room.x + room.w; x += tileSize) {
      for (let y = room.y; y < room.y + room.h; y += tileSize) {
        const noise = ((x * 17 + y * 31) % 19) - 9;

        if (isLab) {
          // Clean laboratory clinical tiles with light blue tint
          const base = 48 + noise;
          ctx.fillStyle = `rgb(${base - 5}, ${base + 8}, ${base + 18})`;
        } else if (isHub) {
          // Control hub reinforced dark green-tinted concrete
          const base = 40 + noise;
          ctx.fillStyle = `rgb(${base - 2}, ${base + 6}, ${base + 2})`;
        } else {
          // Industrial concrete corridor tiles
          const base = 36 + noise;
          ctx.fillStyle = `rgb(${base}, ${base + 2}, ${base + 6})`;
        }

        ctx.fillRect(x + 1, y + 1, tileSize - 2, tileSize - 2);

        // Tile bevel highlights & shadows
        ctx.fillStyle = 'rgba(255, 255, 255, 0.05)';
        ctx.fillRect(x + 1, y + 1, tileSize - 2, 1);
        ctx.fillRect(x + 1, y + 1, 1, tileSize - 2);

        ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
        ctx.fillRect(x + 1, y + tileSize - 2, tileSize - 2, 1);
        ctx.fillRect(x + tileSize - 2, y + 1, 1, tileSize - 2);
      }
    }

    // Tile Grid Lines
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.65)';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(room.x, room.y, room.w, room.h);
  }

  private renderOutdoorFloor(ctx: CanvasRenderingContext2D, room: Room): void {
    // Wet rough asphalt
    ctx.fillStyle = '#1c1f26';
    ctx.fillRect(room.x, room.y, room.w, room.h);

    // Asphalt grain
    for (let i = 0; i < 600; i++) {
      const gx = room.x + Math.random() * room.w;
      const gy = room.y + Math.random() * room.h;
      ctx.fillStyle = Math.random() > 0.5 ? 'rgba(255, 255, 255, 0.06)' : 'rgba(0, 0, 0, 0.25)';
      ctx.fillRect(gx, gy, 3, 3);
    }

    // Rainy water puddles (directly matching the reference image outdoor yard!)
    const puddles = [
      { x: room.x + 220, y: room.y + 200, rx: 90, ry: 50 },
      { x: room.x + 650, y: room.y + 400, rx: 120, ry: 70 },
      { x: room.x + 350, y: room.y + 750, rx: 140, ry: 60 },
      { x: room.x + 800, y: room.y + 850, rx: 100, ry: 45 },
    ];

    for (const p of puddles) {
      ctx.save();
      ctx.beginPath();
      ctx.ellipse(p.x, p.y, p.rx, p.ry, 0, 0, Math.PI * 2);
      ctx.fillStyle = '#111822'; // Dark wet water puddle
      ctx.fill();

      // Puddle edge highlight
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
      ctx.lineWidth = 2;
      ctx.stroke();

      // Water sheen
      ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
      ctx.beginPath();
      ctx.ellipse(p.x - p.rx * 0.2, p.y - p.ry * 0.2, p.rx * 0.5, p.ry * 0.4, -0.2, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    // Overgrown green foliage along the east wall (from reference image)
    const foliageColor = '#14532d';
    for (let f = 0; f < 35; f++) {
      const fx = room.x + room.w - 40 + (Math.random() * 30 - 15);
      const fy = room.y + Math.random() * room.h;
      ctx.fillStyle = foliageColor;
      ctx.beginPath();
      ctx.arc(fx, fy, 16 + Math.random() * 14, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  private renderWallArtwork(ctx: CanvasRenderingContext2D): void {
    for (const w of this.walls) {
      if (w.type === 'fence') {
        // Chain-link fence with metallic posts (from reference screenshot)
        ctx.fillStyle = '#475569';
        ctx.fillRect(w.x, w.y, w.w, w.h);

        ctx.strokeStyle = '#94a3b8';
        ctx.lineWidth = 1;
        ctx.strokeRect(w.x, w.y, w.w, w.h);

        // Fence posts
        ctx.fillStyle = '#cbd5e1';
        if (w.w > w.h) {
          for (let px = w.x; px <= w.x + w.w; px += 40) {
            ctx.fillRect(px - 3, w.y - 2, 6, w.h + 4);
          }
        } else {
          for (let py = w.y; py <= w.y + w.h; py += 40) {
            ctx.fillRect(w.x - 2, py - 3, w.w + 4, 6);
          }
        }
      } else {
        // Solid Metallic Reinforced Wall
        // Wall drop shadow onto floor
        ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
        ctx.fillRect(w.x + 4, w.y + 6, w.w, w.h);

        // Metal base
        ctx.fillStyle = '#1e293b';
        ctx.fillRect(w.x, w.y, w.w, w.h);

        // Metal top plate highlight
        ctx.fillStyle = '#334155';
        ctx.fillRect(w.x + 2, w.y + 2, w.w - 4, w.h - 4);

        // Wall panel seam rivets
        ctx.fillStyle = '#64748b';
        if (w.w > w.h) {
          for (let rx = w.x + 10; rx < w.x + w.w - 10; rx += 30) {
            ctx.fillRect(rx, w.y + 4, 2, 2);
            ctx.fillRect(rx, w.y + w.h - 6, 2, 2);
          }
        } else {
          for (let ry = w.y + 10; ry < w.y + w.h - 10; ry += 30) {
            ctx.fillRect(w.x + 4, ry, 2, 2);
            ctx.fillRect(w.x + w.w - 6, ry, 2, 2);
          }
        }

        // Bright edge bevel
        ctx.strokeStyle = '#475569';
        ctx.lineWidth = 1.5;
        ctx.strokeRect(w.x, w.y, w.w, w.h);
      }
    }
  }

  /**
   * Checks collision of a circular entity against all solid walls and fences
   * and slides smoothly along walls.
   */
  public resolveWallCollision(pos: Vector2, radius: number): Vector2 {
    let nx = pos.x;
    let ny = pos.y;

    for (const w of this.walls) {
      // Find closest point on AABB rectangle to circle
      const closestX = Math.max(w.x, Math.min(nx, w.x + w.w));
      const closestY = Math.max(w.y, Math.min(ny, w.y + w.h));

      const dx = nx - closestX;
      const dy = ny - closestY;
      const d2 = dx * dx + dy * dy;

      if (d2 < radius * radius && d2 > 0.0001) {
        const d = Math.sqrt(d2);
        const overlap = radius - d;
        nx += (dx / d) * overlap;
        ny += (dy / d) * overlap;
      }
    }

    return { x: nx, y: ny };
  }

  /**
   * Checks if a point or line segment intersects any wall (for bullet collision)
   */
  public checkBulletWallCollision(bx: number, by: number): boolean {
    for (const w of this.walls) {
      if (bx >= w.x && bx <= w.x + w.w && by >= w.y && by <= w.y + w.h) {
        return true;
      }
    }
    return false;
  }

  /**
   * Updates player's current room and triggers exploration callbacks
   */
  public updatePlayerRoom(playerPos: Vector2): void {
    for (const r of this.rooms) {
      if (
        playerPos.x >= r.x &&
        playerPos.x <= r.x + r.w &&
        playerPos.y >= r.y &&
        playerPos.y <= r.y + r.h
      ) {
        if (this.currentRoom?.id !== r.id) {
          this.currentRoom = r;
          if (!r.visited) {
            r.visited = true;
            if (this.onRoomEnter) {
              this.onRoomEnter(r);
            }
          }
        }
        break;
      }
    }
  }

  public drawFloor(ctx: CanvasRenderingContext2D): void {
    ctx.drawImage(this.floorCanvas, 0, 0);
  }

  public reset(): void {
    for (const r of this.rooms) {
      r.visited = r.id === 'spawn_hub';
    }
    this.currentRoom = this.rooms[0];
    this.destructibles = [];
    this.nextDestructibleId = 1;
    this.populateDestructibles();
  }
}
