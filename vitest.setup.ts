import { beforeEach, afterEach } from 'vitest'

// Polyfill localStorage with a proper implementation
class Storage implements Storage {
  private data: Record<string, string> = {}

  getItem(key: string): string | null {
    return this.data[key] ?? null
  }

  setItem(key: string, value: string): void {
    this.data[key] = String(value)
  }

  removeItem(key: string): void {
    delete this.data[key]
  }

  clear(): void {
    this.data = {}
  }

  key(index: number): string | null {
    const keys = Object.keys(this.data)
    return keys[index] ?? null
  }

  get length(): number {
    return Object.keys(this.data).length
  }
}

Object.defineProperty(global, 'localStorage', {
  value: new Storage(),
  writable: true,
  configurable: true,
})

// Reset localStorage before each test
beforeEach(() => {
  localStorage.clear()
})
