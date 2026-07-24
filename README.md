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

### Deep links

GitHub Pages only honors a `404.html` placed at the **site root** — a `404.html` inside the `/zephyr/` subdirectory (which `npm run build` still produces, harmless) is never served for a hard reload or direct visit to a deep link like `jonyen.com/zephyr/isaiah/40`; the request 404s before it ever reaches the app.

To fix this, copy this repo's [`deploy/root-404.html`](./deploy/root-404.html) to the **root** of the `jonyen/jonyen.github.io` repo as its `404.html` (merge carefully if a root `404.html` already exists there). It redirects any `/zephyr/...` path to `/zephyr/?p=<original path>`, and `src/main.tsx` restores the original path from that query param before the router boots — so the deep link resolves correctly. Paths outside `/zephyr/` just render a plain "404 — page not found", so it's also safe to use as the site's general root 404 if one isn't set up yet.

This is a one-time manual step outside this repo; it only needs to be redone if the root 404 file is ever overwritten.
