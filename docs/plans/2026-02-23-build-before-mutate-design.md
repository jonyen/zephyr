# Build Before Mutate — Release Rollback Safety

**Date:** 2026-02-23

## Problem

`release.sh` updates `VERSION`, `project.pbxproj`, and `README.md` before running the build. If `build-dmg.sh` fails, those files are left in a mutated state with no commit, requiring manual cleanup.

## Solution

Reorder `release.sh` so the build runs first. Version files are only updated after a successful build.

## New Order

1. Run `build-dmg.sh` with the new version passed via env var (no file changes yet)
2. Update `VERSION`, `project.pbxproj`, `README.md`
3. `git commit`, `git push`, `gh release create`

## Changes Required

### `build-dmg.sh`

Add env var override for `VERSION`. Current line:
```bash
VERSION=$(cat "$ROOT_DIR/VERSION")
```
New behavior: use `$VERSION` env var if set, otherwise fall back to reading the file.

### `release.sh`

Move the "update version files" block (lines 140–151) to after the build step (currently line 155). Pass `VERSION` as an env var when calling `build-dmg.sh`.

## Result

If the build fails, no files have been touched and the working tree stays clean. If it succeeds, version files are updated and the release proceeds to commit.
