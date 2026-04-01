// HexScrollBar.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - HexScrollBar

/// A vertical scrollbar that synchronizes with `HexGridView.scrollOffset`.
///
/// Wraps an `NSScroller` with `.legacy` style so the scrollbar is always visible.
public final class HexScrollBar: NSView {

    // MARK: - Public API

    /// The total number of data rows.
    public var totalRows: Int = 0 { didSet { updateScroller() } }

    /// The number of visible rows in the viewport.
    public var visibleRows: Int = 0 { didSet { updateScroller() } }

    /// Called when the user interacts with the scrollbar.
    public var onScrollOffsetChanged: ((Int) -> Void)?

    /// Updates the scroller position to reflect the given scroll offset.
    ///
    /// - Parameter offset: The first visible row index from `HexGridView`.
    public func updateFromScrollOffset(_ offset: Int) {
        guard !isUpdating else { return }
        currentOffset = offset
        updateScroller()
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScroller()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public func layout() {
        super.layout()
        scroller.frame = bounds
    }

    // MARK: - Private

    private let scroller = NSScroller()
    private var currentOffset: Int = 0
    private var isUpdating = false

    private func setupScroller() {
        scroller.scrollerStyle = .legacy
        scroller.isEnabled = true
        scroller.target = self
        scroller.action = #selector(scrollerAction(_:))
        scroller.autoresizingMask = [.width, .height]
        scroller.frame = bounds
        addSubview(scroller)
    }

    private func updateScroller() {
        let maxOffset = max(0, totalRows - visibleRows)
        guard maxOffset > 0 else {
            scroller.isEnabled = false
            scroller.doubleValue = 0
            scroller.knobProportion = 1.0
            return
        }
        scroller.isEnabled = true
        scroller.doubleValue = Double(currentOffset) / Double(maxOffset)
        scroller.knobProportion = CGFloat(visibleRows) / CGFloat(totalRows)
    }

    @objc private func scrollerAction(_ sender: NSScroller) {
        let maxOffset = max(0, totalRows - visibleRows)
        guard maxOffset > 0 else { return }

        isUpdating = true
        defer { isUpdating = false }

        switch sender.hitPart {
        case .knob, .knobSlot:
            currentOffset = Int(sender.doubleValue * Double(maxOffset))
        case .decrementPage:
            currentOffset = max(0, currentOffset - visibleRows)
        case .incrementPage:
            currentOffset = min(maxOffset, currentOffset + visibleRows)
        case .decrementLine:
            currentOffset = max(0, currentOffset - 1)
        case .incrementLine:
            currentOffset = min(maxOffset, currentOffset + 1)
        default:
            return
        }
        updateScroller()
        onScrollOffsetChanged?(currentOffset)
    }
}
