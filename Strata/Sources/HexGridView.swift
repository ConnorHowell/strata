// HexGridView.swift
// Strata - macOS Hex Editor

import AppKit
import CoreText

// MARK: - HexGridViewDelegate

/// Delegate for handling edits and selection changes in the hex grid.
public protocol HexGridViewDelegate: AnyObject {
    /// Called when a byte is edited.
    func hexGridView(_ view: HexGridView, didEditByteAt offset: Int, value: UInt8)
    /// Called when the selection changes.
    func hexGridView(_ view: HexGridView, didChangeSelection range: Range<Int>?)
}

// MARK: - HexGridView

/// Custom `NSView` subclass that renders a 3-pane hex grid (offset | hex | ASCII).
///
/// Uses viewport-culled rendering via Core Graphics and Core Text.
/// Supports files up to 32 GB via memory-mapped data.
public final class HexGridView: NSView {

    // MARK: - Public API

    /// The piece table providing byte data to display.
    public var dataSource: PieceTable? {
        didSet { needsDisplay = true }
    }

    /// Number of bytes displayed per row.
    public var bytesPerRow: Int = 16 { didSet { needsDisplay = true } }

    /// The currently selected byte range.
    public var selectedRange: Range<Int>? {
        didSet {
            needsDisplay = true
            delegate?.hexGridView(self, didChangeSelection: selectedRange)
        }
    }

    /// Whether insert mode is active (vs overwrite mode).
    public var isInsertMode: Bool = false

    /// Whether the hex pane has focus (vs ASCII pane).
    public var activePaneIsHex: Bool = true { didSet { needsDisplay = true } }

    /// The base used for displaying offsets in the offset column.
    public var offsetBase: OffsetBase = .hex { didSet { needsDisplay = true } }

    /// The number of bytes per visual group in the hex column.
    public var bytesPerGroup: Int = 8 { didSet { needsDisplay = true } }

    /// The character encoding used in the ASCII (text) pane.
    public var textEncoding: TextEncoding = .ascii { didSet { needsDisplay = true } }

    /// Numbered bookmarks (0-9) mapped to byte offsets.
    public var bookmarks: [Int: Int] = [:] { didSet { needsDisplay = true } }

    /// The first visible row index.
    public var scrollOffset: Int = 0 { didSet { needsDisplay = true } }

    /// The cursor byte position.
    public var cursorPosition: Int = 0 {
        didSet {
            needsDisplay = true
            if cursorPosition != oldValue {
                delegate?.hexGridView(self, didChangeSelection: selectedRange)
            }
        }
    }

    /// Whether the first nibble of a hex byte has been entered.
    public var pendingNibble: UInt8?

    /// The delegate for edit and selection callbacks.
    public weak var delegate: HexGridViewDelegate?

    /// The monospace font used for rendering.
    public let gridFont: NSFont = {
        if let consolas = NSFont(name: "Consolas", size: 13) {
            return consolas
        }
        return NSFont(name: "Menlo", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }()

    /// Selection highlight color (#0078D4).
    public let selectionColor = NSColor(
        red: 0x00 / 255.0,
        green: 0x78 / 255.0,
        blue: 0xD4 / 255.0,
        alpha: 1.0
    )

    /// Total number of rows needed to display all data.
    public var totalRows: Int {
        guard let ds = dataSource else { return 0 }
        let len = ds.totalLength
        return len == 0 ? 0 : (len + bytesPerRow - 1) / bytesPerRow
    }

    /// The range of rows currently visible in the viewport.
    public var visibleRowRange: Range<Int> {
        let rowH = GridLayout.rowHeight(for: gridFont)
        guard rowH > 0 else { return 0..<0 }
        let availableHeight = bounds.height - GridLayout.dataOriginY()
        let visibleCount = Int(ceil(availableHeight / rowH)) + 1
        let start = max(0, scrollOffset)
        let end = min(start + visibleCount, totalRows)
        return start..<end
    }

    /// Scrolls the grid to make the given byte offset visible.
    ///
    /// - Parameter offset: The byte offset to scroll to.
    public func scrollToOffset(_ offset: Int) {
        let row = offset / bytesPerRow
        if row < scrollOffset || row >= scrollOffset + visibleRowRange.count {
            scrollOffset = max(0, row - 2)
        }
        cursorPosition = offset
        needsDisplay = true
    }

    /// Toggles focus between the hex and ASCII panes.
    public func togglePane() {
        activePaneIsHex.toggle()
        pendingNibble = nil
        needsDisplay = true
    }

    // MARK: - NSView Overrides

    override public var acceptsFirstResponder: Bool { true }

    override public var isFlipped: Bool { true }

    override public func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawGrid(in: ctx, dirtyRect: dirtyRect)
    }

    override public func keyDown(with event: NSEvent) {
        if let action = KeyBindingMap.action(for: event) {
            handleKeyAction(action)
            return
        }
        guard let chars = event.charactersIgnoringModifiers,
              let char = chars.first,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            super.keyDown(with: event)
            return
        }
        if activePaneIsHex {
            handleHexInput(char)
        } else {
            handleASCIIInput(char)
        }
    }

    /// Accumulated scroll delta for smooth trackpad scrolling.
    private var scrollAccumulator: CGFloat = 0

    /// The byte offset where a drag selection started.
    public var dragAnchor: Int?

    override public func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let extending = event.modifierFlags.contains(.shift)
        if extending, let anchor = dragAnchor {
            if let offset = hitTestByte(at: point) {
                let lo = min(anchor, offset)
                let hi = max(anchor, offset)
                selectedRange = lo..<(hi + 1)
                cursorPosition = offset
            }
        } else if let offset = hitTestByte(at: point) {
            dragAnchor = offset
            selectedRange = nil
            cursorPosition = offset
        }
        pendingNibble = nil
        needsDisplay = true
    }

    override public func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let anchor = dragAnchor, let offset = hitTestByte(at: point) else { return }
        let lo = min(anchor, offset)
        let hi = max(anchor, offset)
        selectedRange = lo..<(hi + 1)
        cursorPosition = offset
        needsDisplay = true
    }

    override public func mouseUp(with event: NSEvent) {
        // Keep selection as-is on mouse up
    }

    override public func scrollWheel(with event: NSEvent) {
        let rowH = GridLayout.rowHeight(for: gridFont)
        guard rowH > 0 else { return }
        scrollAccumulator += -event.scrollingDeltaY
        let rows = Int(scrollAccumulator / rowH)
        if rows != 0 {
            scrollAccumulator -= CGFloat(rows) * rowH
            scrollOffset = max(0, min(scrollOffset + rows, max(0, totalRows - 1)))
            needsDisplay = true
        }
    }

    /// Sets the accessibility identifier for UI testing.
    public func configureAccessibility(identifier: String) {
        setAccessibilityIdentifier(identifier)
    }
}
