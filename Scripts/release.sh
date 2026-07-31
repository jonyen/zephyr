#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Where release-note generation gets its Gemini key when GEMINI_API_KEY isn't exported.
# The Doppler project is named tech-digest rather than automata: the name predates that
# repo's rename, and its CI service token is scoped to it. See jonyen/automata's README.
DOPPLER_GEMINI_PROJECT="${DOPPLER_GEMINI_PROJECT:-tech-digest}"
DOPPLER_GEMINI_CONFIG="${DOPPLER_GEMINI_CONFIG:-prd}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"

# ── colors ────────────────────────────────────────────────────────────────────
BOLD=$(tput bold 2>/dev/null || printf "")
RESET=$(tput sgr0 2>/dev/null || printf "")
CYAN=$(tput setaf 6 2>/dev/null || printf "")
GREEN=$(tput setaf 2 2>/dev/null || printf "")
YELLOW=$(tput setaf 3 2>/dev/null || printf "")
DIM=$(tput dim 2>/dev/null || printf "")

# ── current state ─────────────────────────────────────────────────────────────
CURRENT_VERSION=$(cat "$ROOT_DIR/VERSION")
LAST_TAG=$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_TAG" ]; then
    COMMITS=$(git -C "$ROOT_DIR" log "${LAST_TAG}..HEAD" --oneline 2>/dev/null || echo "")
else
    COMMITS=$(git -C "$ROOT_DIR" log --oneline -20 2>/dev/null || echo "")
fi

# ── header ────────────────────────────────────────────────────────────────────
echo ""
echo "${BOLD}${CYAN}Zephyr Release Script${RESET}"
echo "${DIM}Current: v$CURRENT_VERSION   Last tag: ${LAST_TAG:-none}${RESET}"
echo ""

if [ -z "$COMMITS" ]; then
    echo "${YELLOW}No new commits since $LAST_TAG — nothing to release.${RESET}"
    exit 0
fi

echo "${BOLD}Commits since last release:${RESET}"
echo "$COMMITS" | sed 's/^/  /'
echo ""

# ── check for uncommitted changes ─────────────────────────────────────────────
if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet; then
    echo "${YELLOW}Warning: you have uncommitted changes. They won't be included in this release.${RESET}"
    printf "Continue anyway? [y/${BOLD}N${RESET}]: "
    read -r CONTINUE_DIRTY
    if [[ ! "$CONTINUE_DIRTY" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# ── propose next version (patch bump) ─────────────────────────────────────────
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
PROPOSED_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"

printf "New version [${GREEN}$PROPOSED_VERSION${RESET}]: "
read -r VERSION_INPUT
VERSION="${VERSION_INPUT:-$PROPOSED_VERSION}"
echo ""

# ── generate release notes with AI ────────────────────────────────────────────

# Prefers an exported GEMINI_API_KEY, else pulls it from Doppler so a release can
# be cut without exporting anything by hand.
resolve_gemini_key() {
    if [ -n "${GEMINI_API_KEY:-}" ]; then
        printf "%s" "$GEMINI_API_KEY"
        return 0
    fi
    command -v doppler >/dev/null 2>&1 || return 1
    doppler secrets get GEMINI_API_KEY --plain \
        --project "$DOPPLER_GEMINI_PROJECT" \
        --config "$DOPPLER_GEMINI_CONFIG" 2>/dev/null
}

generate_ai_notes() {
    local version="$1"
    local commits="$2"

    local api_key
    api_key=$(resolve_gemini_key) || return 1
    [ -n "$api_key" ] || return 1

    local payload
    payload=$(jq -n \
        --arg model "$GEMINI_MODEL" \
        --arg commits "$commits" \
        --arg version "$version" \
        '{
            model: $model,
            input: ("Generate release notes for v" + $version + " of Zephyr, a native macOS ESV Bible reader app.\n\nGit commits since last release:\n" + $commits + "\n\nWrite 2–5 concise bullet points under a \"## What'\''s New\" heading. Focus on what users will notice — not implementation details or commit hashes. Plain markdown only.")
        }')

    # The Interactions API returns the reply as text blocks inside model_output steps;
    # output_text is an SDK convenience that doesn't exist over REST, so join them here.
    curl -sf "https://generativelanguage.googleapis.com/v1beta/interactions" \
        -H "x-goog-api-key: $api_key" \
        -H "content-type: application/json" \
        -d "$payload" \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
blocks = [
    block['text']
    for step in data.get('steps', [])
    if step.get('type') == 'model_output'
    for block in step.get('content', [])
    if block.get('type') == 'text' and block.get('text')
]
if not blocks:
    sys.exit(1)
print(''.join(blocks).strip())
"
}

fallback_notes() {
    local commits="$1"
    printf "## What's New\n\n"
    echo "$commits" | sed 's/^[a-f0-9]* /- /'
}

echo "${CYAN}Generating release notes...${RESET}"
if GENERATED_NOTES=$(generate_ai_notes "$VERSION" "$COMMITS" 2>/dev/null) && [ -n "$GENERATED_NOTES" ]; then
    echo "${DIM}(AI-generated)${RESET}"
else
    GENERATED_NOTES=$(fallback_notes "$COMMITS")
    echo "${DIM}(from git log — set GEMINI_API_KEY, or add it to Doppler ${DOPPLER_GEMINI_PROJECT}/${DOPPLER_GEMINI_CONFIG}, to enable AI generation)${RESET}"
fi

# ── show notes and offer to edit ──────────────────────────────────────────────
NOTES_FILE=$(mktemp /tmp/zephyr-release-notes.XXXXXX.md)
printf "%s" "$GENERATED_NOTES" > "$NOTES_FILE"

echo ""
echo "${BOLD}Release notes:${RESET}"
echo "────────────────────────────────────────"
cat "$NOTES_FILE"
echo ""
echo "────────────────────────────────────────"
echo ""
printf "Edit release notes? [y/${BOLD}N${RESET}]: "
read -r EDIT_NOTES
if [[ "$EDIT_NOTES" =~ ^[Yy]$ ]]; then
    "${EDITOR:-nano}" "$NOTES_FILE"
fi

FINAL_NOTES=$(cat "$NOTES_FILE")
rm -f "$NOTES_FILE"

# ── final confirmation ────────────────────────────────────────────────────────
echo ""
echo "${BOLD}Ready to release:${RESET}"
echo "  Version:  ${GREEN}${BOLD}v$VERSION${RESET}"
echo "  Notes:"
echo "$FINAL_NOTES" | sed 's/^/    /'
echo ""
printf "Proceed? [${BOLD}Y${RESET}/n]: "
read -r CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ── build ─────────────────────────────────────────────────────────────────────
echo ""
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

# ── commit, push, release ─────────────────────────────────────────────────────
echo "${CYAN}Committing...${RESET}"
git -C "$ROOT_DIR" add VERSION README.md Zephyr.xcodeproj/project.pbxproj
git -C "$ROOT_DIR" commit -m "chore: release v$VERSION"

echo "${CYAN}Pushing...${RESET}"
git -C "$ROOT_DIR" push origin main

echo "${CYAN}Creating GitHub release...${RESET}"
gh release create "v$VERSION" \
    "$ROOT_DIR/dist/Zephyr-$VERSION.dmg" \
    "$ROOT_DIR/dist/Zephyr.app.zip" \
    --repo jonyen/zephyr \
    --title "v$VERSION" \
    --notes "$FINAL_NOTES"

echo ""
echo "${GREEN}${BOLD}Released v$VERSION successfully!${RESET}"
