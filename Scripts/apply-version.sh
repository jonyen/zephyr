#!/bin/bash
# Writes a version into every file that carries one.
#
# Extracted from release.sh so the release workflow and local tooling can't drift on
# which files need updating.
#
#   Scripts/apply-version.sh 0.9.7
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

VERSION="${1:?usage: apply-version.sh <version>}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "apply-version: expected MAJOR.MINOR.PATCH, got '$VERSION'" >&2
    exit 1
fi

# BSD sed (macOS) needs an argument to -i; GNU sed (CI on Linux, if it ever runs there)
# treats it as the suffix. Passing -i.bak and deleting the backup works on both.
sed_inplace() {
    sed -i.bak "$1" "$2" && rm -f "$2.bak"
}

echo "$VERSION" > "$ROOT_DIR/VERSION"

sed_inplace "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" \
    "$ROOT_DIR/Zephyr.xcodeproj/project.pbxproj"

# Points at jonyen.com rather than the GitHub release: this repo is private, so the
# releases URL 404s for everyone. Matches any previous target so the link is rewritten
# even on the release that moves it.
sed_inplace \
    "s|\[Download Zephyr v[0-9.]*\]([^)]*)|[Download Zephyr v$VERSION](https://jonyen.com/zephyr-updates/Zephyr-$VERSION.dmg)|g" \
    "$ROOT_DIR/README.md"

echo "Version set to $VERSION in VERSION, project.pbxproj, README.md"
