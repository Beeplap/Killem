import type { Vector2 } from './types';

export interface JoystickStick {
  active: boolean;
  pointerId: number | null;
  baseX: number;
  baseY: number;
  currentX: number;
  currentY: number;
  dx: number; // normalized -1 to 1
  dy: number;
  angle: number;
  intensity: number; // 0 to 1
}

export class VirtualJoystickManager {
  public enabled: boolean = false;
  private maxRadius: number = 55;

  public moveStick: JoystickStick = {
    active: false,
    pointerId: null,
    baseX: 0,
    baseY: 0,
    currentX: 0,
    currentY: 0,
    dx: 0,
    dy: 0,
    angle: 0,
    intensity: 0,
  };

  public aimStick: JoystickStick = {
    active: false,
    pointerId: null,
    baseX: 0,
    baseY: 0,
    currentX: 0,
    currentY: 0,
    dx: 0,
    dy: 0,
    angle: 0,
    intensity: 0,
  };

  constructor(canvas: HTMLCanvasElement) {
    // Detect touch capability
    this.detectTouch();

    // Listen for pointer events
    this.bindEvents(canvas);
  }

  private detectTouch(): void {
    const hasTouch =
      'ontouchstart' in window ||
      navigator.maxTouchPoints > 0 ||
      (window.matchMedia && window.matchMedia('(pointer: coarse)').matches);

    if (hasTouch) {
      this.enabled = true;
    }
  }

  public setEnabled(val: boolean): void {
    this.enabled = val;
  }

  private bindEvents(canvas: HTMLCanvasElement): void {
    // If a touch is registered anywhere, enable touch mode automatically
    window.addEventListener(
      'touchstart',
      () => {
        if (!this.enabled) {
          this.enabled = true;
        }
      },
      { passive: true, once: true }
    );

    canvas.addEventListener('pointerdown', (e: PointerEvent) => {
      // Only process touches or if explicitly in touch mode
      if (e.pointerType === 'mouse' && !this.enabled) {
        return;
      }

      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const isLeftHalf = x < rect.width / 2;

      if (isLeftHalf && !this.moveStick.active) {
        this.moveStick.active = true;
        this.moveStick.pointerId = e.pointerId;
        this.moveStick.baseX = x;
        this.moveStick.baseY = y;
        this.moveStick.currentX = x;
        this.moveStick.currentY = y;
        this.moveStick.dx = 0;
        this.moveStick.dy = 0;
        this.moveStick.intensity = 0;
      } else if (!isLeftHalf && !this.aimStick.active) {
        this.aimStick.active = true;
        this.aimStick.pointerId = e.pointerId;
        this.aimStick.baseX = x;
        this.aimStick.baseY = y;
        this.aimStick.currentX = x;
        this.aimStick.currentY = y;
        this.updateStick(this.aimStick, x, y);
      }
    });

    window.addEventListener('pointermove', (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;

      if (this.moveStick.active && this.moveStick.pointerId === e.pointerId) {
        this.updateStick(this.moveStick, x, y);
      } else if (this.aimStick.active && this.aimStick.pointerId === e.pointerId) {
        this.updateStick(this.aimStick, x, y);
      }
    });

    const handlePointerUp = (e: PointerEvent) => {
      if (this.moveStick.active && this.moveStick.pointerId === e.pointerId) {
        this.resetStick(this.moveStick);
      }
      if (this.aimStick.active && this.aimStick.pointerId === e.pointerId) {
        this.resetStick(this.aimStick);
      }
    };

    window.addEventListener('pointerup', handlePointerUp);
    window.addEventListener('pointercancel', handlePointerUp);
  }

  private updateStick(stick: JoystickStick, x: number, y: number): void {
    const rawDx = x - stick.baseX;
    const rawDy = y - stick.baseY;
    const dist = Math.hypot(rawDx, rawDy);

    stick.angle = Math.atan2(rawDy, rawDx);
    stick.intensity = Math.min(1, dist / this.maxRadius);

    if (dist <= this.maxRadius) {
      stick.currentX = x;
      stick.currentY = y;
    } else {
      stick.currentX = stick.baseX + Math.cos(stick.angle) * this.maxRadius;
      stick.currentY = stick.baseY + Math.sin(stick.angle) * this.maxRadius;
    }

    if (dist > 5) {
      stick.dx = (stick.currentX - stick.baseX) / this.maxRadius;
      stick.dy = (stick.currentY - stick.baseY) / this.maxRadius;
    } else {
      stick.dx = 0;
      stick.dy = 0;
    }
  }

  private resetStick(stick: JoystickStick): void {
    stick.active = false;
    stick.pointerId = null;
    stick.dx = 0;
    stick.dy = 0;
    stick.intensity = 0;
  }

  public getMoveVector(): Vector2 {
    if (!this.enabled || !this.moveStick.active) {
      return { x: 0, y: 0 };
    }
    return { x: this.moveStick.dx, y: this.moveStick.dy };
  }

  public isAimingOrShooting(): { shooting: boolean; angle: number | null } {
    if (!this.enabled || !this.aimStick.active || this.aimStick.intensity < 0.25) {
      return { shooting: false, angle: null };
    }
    return {
      shooting: true,
      angle: this.aimStick.angle,
    };
  }

  /**
   * Render virtual on-screen joysticks
   */
  public draw(ctx: CanvasRenderingContext2D, width: number, height: number): void {
    if (!this.enabled) return;

    ctx.save();

    // Default static guide hint positions if not touched yet
    const defaultLeftX = 80;
    const defaultLeftY = height - 90;
    const defaultRightX = width - 80;
    const defaultRightY = height - 90;

    // Draw Move Joystick
    const mBaseX = this.moveStick.active ? this.moveStick.baseX : defaultLeftX;
    const mBaseY = this.moveStick.active ? this.moveStick.baseY : defaultLeftY;
    const mCurX = this.moveStick.active ? this.moveStick.currentX : defaultLeftX;
    const mCurY = this.moveStick.active ? this.moveStick.currentY : defaultLeftY;

    this.drawStickRing(ctx, mBaseX, mBaseY, mCurX, mCurY, 'MOVE', this.moveStick.active);

    // Draw Aim/Shoot Joystick
    const aBaseX = this.aimStick.active ? this.aimStick.baseX : defaultRightX;
    const aBaseY = this.aimStick.active ? this.aimStick.baseY : defaultRightY;
    const aCurX = this.aimStick.active ? this.aimStick.currentX : defaultRightX;
    const aCurY = this.aimStick.active ? this.aimStick.currentY : defaultRightY;

    this.drawStickRing(ctx, aBaseX, aBaseY, aCurX, aCurY, 'FIRE', this.aimStick.active, '#ef4444');

    ctx.restore();
  }

  private drawStickRing(
    ctx: CanvasRenderingContext2D,
    bx: number,
    by: number,
    cx: number,
    cy: number,
    label: string,
    isActive: boolean,
    highlightColor: string = '#38bdf8'
  ): void {
    const alpha = isActive ? 0.65 : 0.25;

    // Outer Ring
    ctx.beginPath();
    ctx.arc(bx, by, this.maxRadius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(15, 23, 42, ${alpha * 0.5})`;
    ctx.fill();
    ctx.lineWidth = 2.5;
    ctx.strokeStyle = isActive ? highlightColor : `rgba(148, 163, 184, ${alpha})`;
    ctx.stroke();

    // Subtle label in center
    ctx.font = '600 11px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha * 0.8})`;
    ctx.fillText(label, bx, by);

    // Thumb Nub
    ctx.beginPath();
    ctx.arc(cx, cy, 24, 0, Math.PI * 2);
    ctx.fillStyle = isActive ? highlightColor : `rgba(203, 213, 225, ${alpha})`;
    ctx.shadowColor = isActive ? highlightColor : 'transparent';
    ctx.shadowBlur = isActive ? 12 : 0;
    ctx.fill();
    ctx.shadowBlur = 0;

    // Inner nub ring
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 2;
    ctx.stroke();
  }
}
