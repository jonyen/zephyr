#!/bin/bash
# Prints release notes for a version to stdout.
#
# Generates them from the commit log with Gemini, falling back to the raw log when no
# API key is reachable. Extracted so the release workflow and any local tooling share
# one implementation instead of drifting apart.
#
#   Scripts/release-notes.sh 0.9.7            # commits since the last tag
#   Scripts/release-notes.sh 0.9.7 v0.9.6..HEAD
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

VERSION="${1:?usage: release-notes.sh <version> [git-range]}"
RANGE="${2:-}"

# Where the Gemini key comes from when GEMINI_API_KEY isn't already exported. The Doppler
# project is named tech-digest rather than automata: the name predates that repo's rename,
# and its CI service token is scoped to it. See jonyen/automata's README.
DOPPLER_GEMINI_PROJECT="${DOPPLER_GEMINI_PROJECT:-tech-digest}"
DOPPLER_GEMINI_CONFIG="${DOPPLER_GEMINI_CONFIG:-prd}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"

if [ -z "$RANGE" ]; then
    LAST_TAG=$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "")
    RANGE="${LAST_TAG:+${LAST_TAG}..HEAD}"
fi

# This is a monorepo but the release is the macOS app, so web/ commits are excluded —
# otherwise the notes describe features that aren't in the DMG. Override with NOTES_PATHSPEC
# (e.g. NOTES_PATHSPEC="web" for a web release).
read -r -a PATHSPEC <<< "${NOTES_PATHSPEC:-. :(exclude)web}"

if [ -n "$RANGE" ]; then
    COMMITS=$(git -C "$ROOT_DIR" log "$RANGE" --oneline --no-merges -- "${PATHSPEC[@]}" 2>/dev/null || echo "")
else
    COMMITS=$(git -C "$ROOT_DIR" log --oneline --no-merges -20 -- "${PATHSPEC[@]}" 2>/dev/null || echo "")
fi

if [ -z "$COMMITS" ]; then
    echo "release-notes: no commits in range ${RANGE:-(last 20)} touching ${PATHSPEC[*]}" >&2
    printf "## What's New\n\n- Maintenance release.\n"
    exit 0
fi

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
    local api_key
    api_key=$(resolve_gemini_key) || return 1
    [ -n "$api_key" ] || return 1

    local payload
    payload=$(jq -n \
        --arg model "$GEMINI_MODEL" \
        --arg commits "$COMMITS" \
        --arg version "$VERSION" \
        '{
            model: $model,
            input: ("Generate release notes for v" + $version + " of Zephyr, a native macOS ESV Bible reader app.\n\nGit commits since last release:\n" + $commits + "\n\nWrite 2–5 concise bullet points under a \"## What'\''s New\" heading. Focus on what users will notice — not implementation details or commit hashes. Plain markdown only.")
        }')

    # The Interactions API returns the reply as text blocks inside model_output steps;
    # output_text is an SDK convenience that doesn't exist over REST, so join them here.
    # gemini-3.6-flash also emits a thought step, which this skips.
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
    printf "## What's New\n\n"
    echo "$COMMITS" | sed 's/^[a-f0-9]* /- /'
}

if NOTES=$(generate_ai_notes 2>/dev/null) && [ -n "$NOTES" ]; then
    printf "%s\n" "$NOTES"
else
    # Diagnostics go to stderr so stdout stays clean for the caller to capture.
    echo "release-notes: no Gemini key reachable, using git log" >&2
    fallback_notes
fi
