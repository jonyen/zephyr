/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/zephyr/' : '/',
  plugins: [react()],
  test: {
    environment: 'jsdom',
    // Node >=22 ships an experimental localStorage stub that shadows jsdom's
    // real implementation; disable it so tests exercise jsdom's localStorage.
    execArgv: ['--no-experimental-webstorage'],
  },
}))
