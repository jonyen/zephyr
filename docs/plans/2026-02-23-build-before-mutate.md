# Build Before Mutate Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorder `release.sh` so the build runs before any version files are modified, eliminating the need for rollback on build failure.

**Architecture:** Pass the new version as a `VERSION` env var to `build-dmg.sh` so it can build with the correct version before `VERSION`, `project.pbxproj`, and `README.md` are touched. On build success, update the files and proceed to commit/push/release as before.

**Tech Stack:** bash, xcodebuild, hdiutil, gh CLI

---

### Task 1: Update `build-dmg.sh` to accept VERSION via env var

**Files:**
- Modify: `Scripts/build-dmg.sh:6`

**Step 1: Read the current line**

Current `Scripts/build-dmg.sh` line 6:
```bash
VERSION=$(cat "$ROOT_DIR/VERSION")
```

**Step 2: Replace it to prefer env var, fall back to file**

```bash
VERSION="${VERSION:-$(cat "$ROOT_DIR/VERSION")}"
```

**Step 3: Verify the file looks correct**

Run: `head -10 Scripts/build-dmg.sh`
Expected: line 6 shows `VERSION="${VERSION:-$(cat "$ROOT_DIR/VERSION")}"`

**Step 4: Commit**

```bash
git add Scripts/build-dmg.sh
git commit -m "feat: allow build-dmg.sh to accept VERSION via env var"
```

---

### Task 2: Reorder `release.sh` — build first, then update files

**Files:**
- Modify: `Scripts/release.sh`

**Context:** Currently the script does this at lines 140–155:

```bash
# ── update version files ──────────────────────────────────────────────────────
echo "${CYAN}Updating version files...${RESET}"

echo "$VERSION" > "$ROOT_DIR/VERSION"

sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" \
    "$ROOT_DIR/Zephyr.xcodeproj/project.pbxproj"

sed -i '' \
    "s|\[Download Zephyr v[0-9.]*\](https://github.com/jonyen/zephyr/releases/download/v[0-9.]*/Zephyr-[0-9.]*.dmg)|[Download Zephyr v$VERSION](https://github.com/jonyen/zephyr/releases/download/v$VERSION/Zephyr-$VERSION.dmg)|g" \
    "$ROOT_DIR/README.md"

# ── build ─────────────────────────────────────────────────────────────────────
echo "${CYAN}Building DMG...${RESET}"
"$SCRIPT_DIR/build-dmg.sh"
```

**Step 1: Replace that block so build runs first**

Replace the entire block above with:

```bash
# ── build ─────────────────────────────────────────────────────────────────────
echo "${CYAN}Building DMG...${RESET}"
VERSION="$VERSION" "$SCRIPT_DIR/build-dmg.sh"

# ── update version files ──────────────────────────────────────────────────────
echo "${CYAN}Updating version files...${RESET}"

echo "$VERSION" > "$ROOT_DIR/VERSION"

sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" \
    "$ROOT_DIR/Zephyr.xcodeproj/project.pbxproj"

sed -i '' \
    "s|\[Download Zephyr v[0-9.]*\](https://github.com/jonyen/zephyr/releases/download/v[0-9.]*/Zephyr-[0-9.]*.dmg)|[Download Zephyr v$VERSION](https://github.com/jonyen/zephyr/releases/download/v$VERSION/Zephyr-$VERSION.dmg)|g" \
    "$ROOT_DIR/README.md"
```

**Step 2: Verify the ordering in the file**

Run: `grep -n "Building DMG\|Updating version files" Scripts/release.sh`
Expected output (build line number is lower than update line number):
```
NNN:echo "${CYAN}Building DMG...${RESET}"
MMM:echo "${CYAN}Updating version files...${RESET}"
```
where NNN < MMM.

**Step 3: Commit**

```bash
git add Scripts/release.sh
git commit -m "feat: build before updating version files in release.sh"
```

---

### Task 3: Manual smoke test

**Step 1: Verify a dry run with a fake build failure**

Temporarily break `build-dmg.sh` by adding `exit 1` after the shebang, run `Scripts/release.sh`, confirm it exits without touching `VERSION`, `project.pbxproj`, or `README.md`.

```bash
# Check working tree is clean after simulated failure
git diff --stat
```
Expected: no output (no modified files).

**Step 2: Revert the temporary `exit 1`** if you added it.

**Step 3: Confirm `VERSION` still reads old value after simulated failure**

```bash
cat VERSION
```
Expected: unchanged version number.
