import type { Vector2 } from './types';

export function distanceSq(x1: number, y1: number, x2: number, y2: number): number {
  const dx = x2 - x1;
  const dy = y2 - y1;
  return dx * dx + dy * dy;
}

export function distance(x1: number, y1: number, x2: number, y2: number): number {
  return Math.hypot(x2 - x1, y2 - y1);
}

export function normalize(x: number, y: number): Vector2 {
  const len = Math.hypot(x, y);
  if (len === 0) {
    return { x: 0, y: 0 };
  }
  return { x: x / len, y: y / len };
}

export function clamp(val: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, val));
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function checkCircleCollision(
  x1: number,
  y1: number,
  r1: number,
  x2: number,
  y2: number,
  r2: number
): boolean {
  const rSum = r1 + r2;
  return distanceSq(x1, y1, x2, y2) <= rSum * rSum;
}

export interface AABB {
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
}

export function checkAABBCollision(boxA: AABB, boxB: AABB): boolean {
  return (
    boxA.minX <= boxB.maxX &&
    boxA.maxX >= boxB.minX &&
    boxA.minY <= boxB.maxY &&
    boxA.maxY >= boxB.minY
  );
}

export function circleToAABB(x: number, y: number, radius: number): AABB {
  return {
    minX: x - radius,
    minY: y - radius,
    maxX: x + radius,
    maxY: y + radius,
  };
}
