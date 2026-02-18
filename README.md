# Zephyr

A minimalistic ESV Bible reader for macOS.

Zephyr is a native Mac app built with SwiftUI that puts Scripture front and center — no accounts, no ads, no distractions. Just the Word.

## Download

**[Download Zephyr v0.8.1](https://github.com/jonyen/zephyr/releases/download/v0.8.1/Zephyr-0.8.1.dmg)** (macOS 14+)

Open the DMG and drag Zephyr to your Applications folder.

## Features

- **Full ESV Bible** — All 66 books, offline and instantly accessible
- **Spotlight Integration** — Search for any verse or passage directly from macOS Spotlight
- **Bookmarks** — Save your place and quickly return to passages
- **Highlights** — Mark verses with color highlights as you read
- **Private Notes** — Add personal notes to any verse range, stored locally on your device
- **Bible Scrubber** — Scan through the Bible with a scrubber that feels like flipping through a physical book
- **Keyword Search** — Full-text search across the entire Bible
- **Red Letter** — Words of Christ displayed in red
- **Reading History** — Automatically tracks where you've been
- **Completely Free** — No ads, no in-app purchases, no accounts, no tracking

## Building from Source

Requires Xcode 16+ and macOS 14+.

```bash
# Clone the repository
git clone https://github.com/jonyen/zephyr.git
cd zephyr

# Build and create DMG
./Scripts/build-dmg.sh
```

The DMG will be created in the `dist/` directory.

## License

All Scripture quotations are from the ESV (English Standard Version) Bible.
