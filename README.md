<p align="center">
  <img src="strata-logo.svg" alt="Strata" width="128" height="128">
</p>

<h1 align="center">Strata</h1>

<p align="center">
  A native macOS hex editor built with Swift and AppKit.<br>
  Inspired by <a href="https://mh-nexus.de/en/hxd/">HxD</a>. Fast, lightweight, and open source.
</p>

<p align="center">
  <a href="#why">Why?</a> &middot;
  <a href="#features">Features</a> &middot;
  <a href="#installation">Installation</a> &middot;
  <a href="#building-from-source">Building</a> &middot;
  <a href="#contributing">Contributing</a> &middot;
  <a href="#license">License</a>
</p>

---

## Why?

I built this (heavily) with the help of [Claude Code](https://claude.ai/claude-code) because I've always wanted a macOS-native hex editor that is almost identical to [HxD](https://mh-nexus.de/en/hxd/) — because I don't like change. It also seemed like a good test for how far I could push almost entirely AI-driven development of a brand new application to serve my specific use case.

Feel free to raise any requests or bugs in an [Issue](../../issues) — I'll get Claude to fix it ;)

## Features

- **Piece table editing engine** — non-destructive edits with full undo/redo
- **Memory-mapped I/O** — handles large files efficiently
- **Multi-tab sessions** — open and switch between multiple files
- **3-pane hex grid** — offset, hex, and decoded text columns with viewport-culled rendering
- **Data inspector** — view bytes as integers, floats, and strings with endianness toggle
- **Find & Replace** — search by hex, ASCII, or wildcard patterns
- **Checksums** — CRC-16, CRC-32, MD5, SHA-1, SHA-256
- **File comparison** — side-by-side diff powered by Myers algorithm
- **Byte statistics** — histogram of byte value distribution
- **Format support** — import/export Intel HEX and Motorola S-Record
- **File tools** — concatenate and split files
- **Configurable display** — adjustable bytes per row, byte grouping, offset base, and character encoding
- **Keyboard-driven** — full keybinding system with customizable shortcuts

## Requirements

- macOS 13 (Ventura) or later

## Installation

### Download

Grab the latest `.app` from the [Releases](../../releases) page.

### Homebrew (coming soon)

```bash
brew install --cask strata
```

## Building from Source

```bash
git clone https://github.com/connorhowell/strata.git
cd strata
make build
```

### Available Make targets

| Command      | Description                          |
|-------------|--------------------------------------|
| `make build` | Debug build via xcodebuild          |
| `make test`  | Run all tests (77 unit + 7 UI)      |
| `make lint`  | Run SwiftLint                       |
| `make clean` | Clean build artifacts               |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

## License

[MIT](LICENSE) — Copyright (c) 2025 Connor Howell
