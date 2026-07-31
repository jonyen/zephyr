# Releasing

## Cutting a release

```
./Scripts/release.sh          # prompts for a version, then dispatches and follows CI
gh workflow run release.yml -f version=0.9.9    # or dispatch directly
```

CI builds, tests, signs, publishes to `jonyen.com/zephyr-updates`, commits the version bump,
and creates the GitHub release. Everything destructive happens after the build succeeds, so a
failure in the early steps leaves `main` and the update feed untouched.

Required secrets on `jonyen/zephyr`:

| Secret | Used for |
| --- | --- |
| `UPDATE_SIGNING_KEY` | Signing the update payload |
| `DEPLOY_TOKEN` | Publishing to `jonyen/jonyen-website` |
| `GEMINI_API_KEY` | Generating release notes (falls back to the git log) |

## Why updates aren't served from GitHub

This repo is private, so `api.github.com/repos/jonyen/zephyr/releases/latest` returns 404 to
an unauthenticated client — which the app is. Updates are served from
`jonyen.com/zephyr-updates` instead, published by the release workflow.

That directory is a **sibling** of `public/zephyr`, not inside it: `deploy-web.yml` publishes
the web app there with `keep_files: false`, which would delete the update feed on its next
run.

## Rotating the signing key

`installAndRelaunch` replaces the running app bundle with whatever it downloaded, so payloads
are signed with Ed25519 and verified before install. The app trusts a **list** of public keys
(`updatePublicKeys` in `UpdateService.swift`) specifically so the key can change without
stranding installs.

Rotation takes two releases. Doing it in one strands every existing copy, because the build
that carries the new key would itself be signed with the new key — and the copies that need
it are exactly the ones that don't trust it yet.

**Release 1 — introduce the new key, keep signing with the old one.**

```bash
swift Scripts/sign-update.swift keygen     # save the private half somewhere durable
```

Add the new public key to `updatePublicKeys` *below* the current one. Leave
`UPDATE_SIGNING_KEY` alone. Cut a release. Existing installs verify against the old key,
accept the update, and now trust both.

**Release 2 — switch signing to the new key.**

```bash
gh secret set UPDATE_SIGNING_KEY --repo jonyen/zephyr    # the new private key
```

Remove the old public key from `updatePublicKeys`. Cut a release. Everyone who took release 1
verifies against the new key.

Wait for release 1 to be widely installed before starting release 2 — anyone still on an
older build is stranded by it.

### If the key is lost

Releases fail at the signing step, before anything is published; installed copies keep
working. To resume you must generate a new key, update both the secret and
`updatePublicKeys`, and cut a release — but every copy installed before that release will
reject it and needs a manual reinstall from the DMG. There is no way to sign around this,
which is why the private key belongs somewhere durable.

CI parses `updatePublicKeys` out of `UpdateService.swift` and fails the build if the
signature matches none of them, so a divergence between the secret and the app is caught
before it can be published.
