# Strata - macOS Hex Editor

Native macOS hex editor built in Swift/AppKit targeting macOS 13+. Visual clone of HxD.

## Build & Test

```bash
make build        # xcodebuild debug build
make test         # run all tests (146 unit + 7 UI)
make lint         # swiftlint
make clean        # clean build artifacts
```

Or directly:
```bash
xcodebuild -scheme Strata -configuration Debug build
xcodebuild -scheme Strata -configuration Debug -destination 'platform=macOS' test
```

## Architecture

- **NIB-free programmatic UI** — no storyboards, no xibs. App entry is `main.swift` with explicit `NSApplication.shared` setup (NOT `@main`).
- **Piece table** edit engine (`PieceTable.swift`) — non-destructive editing with `UndoManager` support.
- **Viewport-culled Core Graphics/Core Text rendering** — `HexGridView` is a custom `NSView` (`isFlipped = true`) that draws only visible rows. Text requires `CGAffineTransform(scaleX: 1, y: -1)` on `textMatrix` before `CTLineDraw`.
- **Session manager** — multi-tab support via `SessionManager` + `FileSession`, each with own piece table and undo stack.
- **Memory-mapped I/O** — files opened via `Data(contentsOf:options:.mappedIfSafe)` for large file support.
- **Strings engine** — memory-mapped ASCII + UTF-16 LE/BE string extraction (`StringsEngine.swift`) with configurable min length. Uses `withUnsafeBytes` pointer scanning for minimal allocations.
- **FindCrypt engine** — signature-based crypto constant detection (`FindCryptEngine.swift`) with 126-entry Ghidra-sourced JSON signature database, supporting both endiannesses and partial matching.

## Project Layout

```
Strata/Sources/
  main.swift                  # App entry point
  AppDelegate.swift           # Window setup, menus, layout
  AppDelegate+Actions.swift   # Menu actions, delegate conformances
  AppDelegate+Tools.swift     # Tool actions (checksums, strings, findcrypt, compare, etc.)
  HexGridView.swift           # NSView subclass — 3-pane hex grid
  HexGridViewDrawing.swift    # Core Graphics rendering, GridLayout, HxD colors
  HexGridViewInput.swift      # Keyboard/mouse input, clipboard, hit testing
  PieceTable.swift            # Piece table data structure
  FileSession.swift           # FileSession + SessionManager
  DiffEngine.swift            # Myers diff algorithm
  ChecksumEngine.swift        # CRC-16/32, MD5, SHA-1, SHA-256/384/512
  StringsEngine.swift         # ASCII + UTF-16 string extraction from binary data
  FindCryptEngine.swift       # Crypto constant signature scanner
  KeyBindings.swift           # KeyAction enum, KeyCombination, KeyBindingMap
  Formats/
    IntelHex.swift            # Intel HEX import/export
    SRecord.swift             # Motorola S-Record import/export
  Views/
    DataInspector.swift       # Right sidebar — binary/int/float with endianness toggle
    FindReplacePanel.swift    # Find & Replace with hex/ASCII/wildcard
    GoToOffsetSheet.swift     # Go To Offset modal sheet
    ChecksumSheet.swift       # Checksum algorithm selection sheet
    ChecksumResultsPanel.swift # Checksum results with compare support
    StringsSheet.swift        # Strings extraction config sheet
    StringsResultsPanel.swift # Strings results table with navigation
    FindCryptResultsPanel.swift # FindCrypt results table with navigation
    DiffView.swift            # Side-by-side diff view
    TabBar.swift              # Tab bar with close buttons
Strata/Resources/
  FindCryptSignatures.json    # Crypto constant signature database (AES, DES, SHA, etc.)

StrataTests/                  # XCTest unit tests (146 tests)
StrataUITests/                # XCUITest UI tests (7 tests)
```

## Code Conventions

- **SwiftLint enforced** — see `.swiftlint.yml`
- No force unwrapping (`!`) — severity: error
- Max line length: 120 (warning), 150 (error)
- Max file length: 400 (warning), 500 (error)
- Trailing commas required in multi-line collections
- Doc comments on all public APIs
- `// MARK: -` sections in every file (Public API, Private, etc.)
- All keybindings go through `KeyBindingMap` — never hardcode key checks
- Properties shared across extension files use `internal` access (not `private`)

## Key Gotchas

- `@main` does NOT work for NIB-free apps — it calls `NSApplicationMain` which expects a NIB. Use `main.swift` instead.
- Core Text in flipped NSView needs `ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)` before drawing.
- `UndoManager.groupsByEvent` must be `false` in tests with explicit `beginUndoGrouping()`/`endUndoGrouping()` for predictable undo behavior.
- Redo requires nested `registerUndo` inside the undo handler (see `PieceTable.registerUndoRestore`).
- `NSView.tag` is read-only — use custom properties like `tabIndex` instead.
- **NSButton radio groups require a shared non-nil action** — `NSButton(radioButtonWithTitle:target:action:)` with `target: nil, action: nil` will NOT auto-group. Each radio group needs a shared `@objc` action method, and the handler must manually set `.on`/`.off` for all buttons in the group (e.g. `for btn in group { btn.state = btn === sender ? .on : .off }`).
- **NSBox contentView** — do NOT replace `relBox.contentView = myView`. Instead, add subviews to the existing `relBox.contentView` with constraints. Replacing it breaks NSBox sizing.
- **NSTableView dataSource on zero-frame views** — do NOT set `dataSource`/`delegate` during `init` when the view has `frame: .zero`. NSTableView will try to create cells for ALL rows (not just visible ones), causing runaway memory allocation. Defer to `viewDidMoveToWindow()` so the scroll view has a real frame to clip against.
