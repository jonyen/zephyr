# Zephyr Web

A web version of [Zephyr](https://github.com/jonyen/zephyr), the minimalist ESV Bible reader for macOS. No accounts, no tracking — highlights, bookmarks, and history live in your browser's localStorage.

Live at [jonyen.com/zephyr](https://jonyen.com/zephyr).

## Develop

    npm install
    npm run dev        # http://localhost:5173
    npm test           # vitest
    npm run build      # production build with /zephyr/ base

## Deploy

Pushes to `main` build and publish `dist/` into `jonyen/jonyen.github.io` under `/zephyr/` via GitHub Actions (requires the `DEPLOY_TOKEN` repo secret — a fine-grained PAT with write access to that repo).
