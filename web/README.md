# Zephyr Web

A web version of [Zephyr](../README.md), the minimalist ESV Bible reader for macOS. No accounts, no tracking — highlights, bookmarks, and history live in your browser's localStorage.

Live at [jonyen.com/zephyr](https://jonyen.com/zephyr).

This app lives in the `web/` directory of the [jonyen/zephyr](https://github.com/jonyen/zephyr) monorepo, alongside the macOS app at the repo root. It was developed in a separate `jonyen/zephyr-web` repo through July 2026 and merged in with its history intact.

## Develop

All npm commands run from this `web/` directory, not the repo root.

    npm install
    npm run dev        # http://localhost:5173
    npm test           # vitest
    npm run build      # production build with /zephyr/ base

## Deploy

The workflow is [`.github/workflows/deploy-web.yml`](../.github/workflows/deploy-web.yml) at the **repo root** — GitHub Actions only reads workflows from the root `.github/workflows/`, so it cannot live in this directory. It is filtered on `paths: web/**`, so commits that only touch the macOS app don't trigger a web deploy.

Pushes to `main` that touch `web/` build and publish `web/dist/` into `jonyen/jonyen-website` under `public/zephyr/`. That repo is a Create React App site whose own workflow deploys on every push to its `main`; CRA copies `public/` verbatim into the build, so the pushed files go live at [jonyen.com/zephyr](https://jonyen.com/zephyr/) on its next deploy with no changes to that workflow.

### Required secrets

The deploy needs a `DEPLOY_TOKEN` secret — a fine-grained PAT with `contents: write` access to `jonyen/jonyen-website`.

**This secret must be created on `jonyen/zephyr`.** Repository secrets do not follow code across repos, so the one that existed on `jonyen/zephyr-web` does not carry over from the merge. Until it's added, the deploy step will fail on an empty token:

    gh secret set DEPLOY_TOKEN --repo jonyen/zephyr

It also needs a `TEXT_REPO_SSH_KEY` secret — the private half of a read-only deploy key on `jonyen/zephyr-esv-text`, the private repo holding the scripture text. `DEPLOY_TOKEN` cannot be reused: it is scoped to `jonyen-website` and cannot read the text repo. To rotate or recreate the key:

    ssh-keygen -t ed25519 -N '' -C 'zephyr web deploy (read-only)' -f zephyr-text-deploy
    gh repo deploy-key add zephyr-text-deploy.pub --repo jonyen/zephyr-esv-text \
      --title 'zephyr web deploy (read-only)'
    gh secret set TEXT_REPO_SSH_KEY --repo jonyen/zephyr < zephyr-text-deploy
    rm zephyr-text-deploy zephyr-text-deploy.pub

A deploy key rather than a PAT because it is scoped to that one repository, is read-only, and does not expire — a lapsed PAT would take the site down again.

The book JSONs are not committed here, so without this key the build has nothing to serve. The workflow fetches the text before building and verifies `dist/data/` holds all 67 files before publishing, so a credential problem fails the run instead of quietly replacing the live site with an empty reader.

The old `jonyen/zephyr-web` repo should be archived with a pointer here; leaving it active means two workflows racing to publish the same `public/zephyr` directory.

### Deep links

GitHub Pages only honors a `404.html` placed at the **site root** — a `404.html` inside the `/zephyr/` subdirectory (which `npm run build` still produces, harmless) is never served for a hard reload or direct visit to a deep link like `jonyen.com/zephyr/isaiah/40`; the request 404s before it ever reaches the app.

To fix this, copy this repo's [`deploy/root-404.html`](./deploy/root-404.html) to `jonyen/jonyen-website`'s `public/404.html` (none exists there today, so nothing is clobbered; CRA copies it to the served site root). It redirects any `/zephyr/...` path to `/zephyr/?p=<original path>`, and `src/main.tsx` restores the original path from that query param before the router boots — so the deep link resolves correctly. Paths outside `/zephyr/` just render a plain "404 — page not found", so it's also safe to use as the site's general root 404 if one isn't set up yet.

This is a one-time manual step outside this repo; it only needs to be redone if the root 404 file is ever overwritten.
