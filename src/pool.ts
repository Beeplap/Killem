/**
 * High-performance Object Pool pattern to eliminate garbage collection pauses.
 */
export class ObjectPool<T extends { active: boolean }> {
  private pool: T[];
  private factory: (index: number) => T;
  private resetFn?: (item: T) => void;

  constructor(factory: (index: number) => T, initialSize: number = 200, resetFn?: (item: T) => void) {
    this.factory = factory;
    this.resetFn = resetFn;
    this.pool = new Array<T>(initialSize);
    for (let i = 0; i < initialSize; i++) {
      const item = this.factory(i);
      item.active = false;
      this.pool[i] = item;
    }
  }

  /**
   * Retrieves an inactive item from the pool or expands if exhausted.
   */
  public acquire(): T {
    // Look for first inactive element
    for (let i = 0; i < this.pool.length; i++) {
      const item = this.pool[i];
      if (!item.active) {
        item.active = true;
        if (this.resetFn) {
          this.resetFn(item);
        }
        return item;
      }
    }

    // Pool exhausted, expand by 20%
    const expandSize = Math.max(16, Math.floor(this.pool.length * 0.2));
    const startIdx = this.pool.length;
    for (let i = 0; i < expandSize; i++) {
      const newItem = this.factory(startIdx + i);
      newItem.active = false;
      this.pool.push(newItem);
    }

    const acquired = this.pool[startIdx];
    acquired.active = true;
    if (this.resetFn) {
      this.resetFn(acquired);
    }
    return acquired;
  }

  /**
   * Releases an item back to inactive state.
   */
  public release(item: T): void {
    item.active = false;
  }

  /**
   * Releases all items in the pool.
   */
  public releaseAll(): void {
    for (let i = 0; i < this.pool.length; i++) {
      this.pool[i].active = false;
    }
  }

  /**
   * Iterates through active items in the pool without allocating an array.
   */
  public forEachActive(callback: (item: T, index: number) => void): void {
    for (let i = 0; i < this.pool.length; i++) {
      const item = this.pool[i];
      if (item.active) {
        callback(item, i);
      }
    }
  }

  public getActiveCount(): number {
    let count = 0;
    for (let i = 0; i < this.pool.length; i++) {
      if (this.pool[i].active) count++;
    }
    return count;
  }

  public getCapacity(): number {
    return this.pool.length;
  }
}
