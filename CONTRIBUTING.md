# Contributing to Strata

Thanks for your interest in contributing to Strata! This document covers the basics to get you started.

## Getting Started

1. Fork the repository
2. Clone your fork and create a feature branch:
   ```bash
   git clone https://github.com/your-username/strata.git
   cd strata
   git checkout -b my-feature
   ```
3. Build and run:
   ```bash
   make build
   ```

## Development

### Prerequisites

- Xcode 15+ (Swift 5.9+)
- macOS 13+
- [SwiftLint](https://github.com/realm/SwiftLint) (for linting)

### Architecture

Strata is a **NIB-free programmatic AppKit app**. There are no storyboards or xibs — all UI is built in code. The entry point is `main.swift` with explicit `NSApplication.shared` setup (not `@main`).

Key components:

- **PieceTable** — the core edit engine. All data modifications go through the piece table, which supports non-destructive editing with full undo/redo.
- **HexGridView** — a custom `NSView` that renders the 3-pane hex grid using Core Graphics and Core Text. Only visible rows are drawn (viewport culling).
- **SessionManager / FileSession** — manages multi-tab support. Each session has its own piece table and undo stack.

### Code Style

SwiftLint is enforced. Run `make lint` before submitting.

Key rules:
- No force unwrapping (`!`) — this is a build error
- Max line length: 120 characters (warning), 150 (error)
- Max file length: 400 lines (warning), 500 (error)
- Trailing commas required in multi-line collections
- Doc comments on all public APIs
- `// MARK: -` sections in every file
- All keybindings go through `KeyBindingMap` — never hardcode key checks

### Testing

```bash
make test
```

The test suite includes 77 unit tests and 7 UI tests. Please add tests for new functionality and ensure existing tests pass before submitting a PR.

## Submitting Changes

1. Make sure all tests pass: `make test`
2. Make sure linting passes: `make lint`
3. Write clear commit messages that explain *why*, not just *what*
4. Open a pull request against `main`
5. Describe what your PR does and link any relevant issues

## Reporting Bugs

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Sample file if applicable (or describe its characteristics)

## Feature Requests

Open an issue describing the feature and why it would be useful. For larger changes, it's best to discuss in an issue before starting work.
