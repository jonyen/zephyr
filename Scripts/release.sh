#!/bin/bash
# Kicks off the release workflow on GitHub Actions and follows it.
#
# The build, notes, version bump and publish all happen in CI (.github/workflows/release.yml)
# so there is one release path rather than a local one and a CI one drifting apart. This
# script is just the gesture: pick a version, confirm, dispatch, watch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WORKFLOW="release.yml"

# ── colors ────────────────────────────────────────────────────────────────────
BOLD=$(tput bold 2>/dev/null || printf "")
RESET=$(tput sgr0 2>/dev/null || printf "")
CYAN=$(tput setaf 6 2>/dev/null || printf "")
GREEN=$(tput setaf 2 2>/dev/null || printf "")
YELLOW=$(tput setaf 3 2>/dev/null || printf "")
DIM=$(tput dim 2>/dev/null || printf "")

command -v gh >/dev/null 2>&1 || { echo "gh CLI is required: https://cli.github.com"; exit 1; }

# ── current state ─────────────────────────────────────────────────────────────
CURRENT_VERSION=$(cat "$ROOT_DIR/VERSION")
LAST_TAG=$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_TAG" ]; then
    COMMITS=$(git -C "$ROOT_DIR" log "${LAST_TAG}..HEAD" --oneline 2>/dev/null || echo "")
else
    COMMITS=$(git -C "$ROOT_DIR" log --oneline -20 2>/dev/null || echo "")
fi

echo ""
echo "${BOLD}${CYAN}Zephyr Release${RESET}"
echo "${DIM}Current: v$CURRENT_VERSION   Last tag: ${LAST_TAG:-none}${RESET}"
echo ""

if [ -z "$COMMITS" ]; then
    echo "${YELLOW}No new commits since $LAST_TAG — nothing to release.${RESET}"
    exit 0
fi

echo "${BOLD}Commits since last release:${RESET}"
echo "$COMMITS" | sed 's/^/  /'
echo ""

# CI releases whatever is on origin/main, so anything unpushed simply won't ship.
if [ -n "$(git -C "$ROOT_DIR" log origin/main..HEAD --oneline 2>/dev/null)" ]; then
    echo "${YELLOW}Warning: you have commits that aren't pushed. CI releases origin/main,${RESET}"
    echo "${YELLOW}so these won't be included:${RESET}"
    git -C "$ROOT_DIR" log origin/main..HEAD --oneline | sed 's/^/  /'
    echo ""
fi

if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet; then
    echo "${YELLOW}Warning: you have uncommitted changes. They won't be included.${RESET}"
    echo ""
fi

# ── propose next version (patch bump) ─────────────────────────────────────────
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
PROPOSED_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

printf "New version [${GREEN}$PROPOSED_VERSION${RESET}]: "
read -r VERSION_INPUT
VERSION="${VERSION_INPUT:-$PROPOSED_VERSION}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Expected MAJOR.MINOR.PATCH, got '$VERSION'"
    exit 1
fi
echo ""

echo "${BOLD}Ready to release:${RESET}"
echo "  Version:  ${GREEN}${BOLD}v$VERSION${RESET}"
echo "  Runs on:  GitHub Actions (macos-latest)"
echo "  Notes:    generated in CI from the commit log"
echo ""
printf "Proceed? [${BOLD}Y${RESET}/n]: "
read -r CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ── dispatch and follow ───────────────────────────────────────────────────────
echo ""
echo "${CYAN}Dispatching $WORKFLOW...${RESET}"
gh workflow run "$WORKFLOW" --ref main -f version="$VERSION"

# The run needs a moment to appear before it can be watched.
echo "${DIM}Waiting for the run to start...${RESET}"
RUN_ID=""
for _ in $(seq 1 30); do
    sleep 2
    RUN_ID=$(gh run list --workflow "$WORKFLOW" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
    [ -n "$RUN_ID" ] && break
done

if [ -z "$RUN_ID" ]; then
    echo "${YELLOW}Dispatched, but couldn't find the run. Check: gh run list --workflow $WORKFLOW${RESET}"
    exit 0
fi

gh run watch "$RUN_ID" --exit-status || {
    echo ""
    echo "${YELLOW}Release failed. Logs: gh run view $RUN_ID --log-failed${RESET}"
    exit 1
}

echo ""
echo "${GREEN}${BOLD}Released v$VERSION.${RESET}"
echo "${DIM}Edit the notes if needed: gh release edit v$VERSION${RESET}"
