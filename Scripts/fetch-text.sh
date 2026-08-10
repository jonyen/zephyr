#!/usr/bin/env bash
# Populate the scripture text resources this app needs at build time.
#
# The ESV text is copyrighted by Crossway and is not redistributed with this
# source. It lives in a separate private repository; this script pulls it into
# place. Set ZEPHYR_TEXT_REPO to point somewhere else if you have your own
# licensed source for the text.
#
# Layout it produces:
#   ESVBible/Resources/<Book>.json   66 files, macOS app bundle
#   web/public/data/<Book>.json      66 files, web build

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEXT_REPO="${ZEPHYR_TEXT_REPO:-git@github.com:jonyen/zephyr-esv-text.git}"
CACHE_DIR="${ZEPHYR_TEXT_CACHE:-$REPO_ROOT/.text-cache}"

MACOS_DEST="$REPO_ROOT/ESVBible/Resources"
WEB_DEST="$REPO_ROOT/web/public/data"

if [ -d "$CACHE_DIR/.git" ]; then
  echo "==> Updating text cache at $CACHE_DIR"
  git -C "$CACHE_DIR" pull --ff-only --quiet
else
  echo "==> Cloning text into $CACHE_DIR"
  rm -rf "$CACHE_DIR"
  if ! git clone --depth 1 --quiet "$TEXT_REPO" "$CACHE_DIR"; then
    cat >&2 <<EOF

Could not clone $TEXT_REPO

That repository is private — it holds ESV text, which is licensed for API
access rather than redistribution. To build you need either access to it or
your own copy of the text, laid out as:

    macos/<Book>.json   66 files
    web/<Book>.json     66 files

Point ZEPHYR_TEXT_REPO at your own source, or ZEPHYR_TEXT_CACHE at a directory
that already has that layout.
EOF
    exit 1
  fi
fi

for pair in "macos:$MACOS_DEST" "web:$WEB_DEST"; do
  src="$CACHE_DIR/${pair%%:*}"
  dest="${pair#*:}"
  if [ ! -d "$src" ]; then
    echo "Missing $src in the text repository" >&2
    exit 1
  fi
  mkdir -p "$dest"
  cp "$src"/*.json "$dest"/
  echo "==> $(ls -1 "$src"/*.json | wc -l | tr -d ' ') books -> ${dest#$REPO_ROOT/}"
done

echo "==> Text resources ready"
