// MinimapView.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - MinimapView

/// A vertical minimap that shows a byte-class heatmap of the entire file with a draggable viewport.
public final class MinimapView: NSView {

    // MARK: - Public API

    /// The piece table providing byte data.
    public var dataSource: PieceTable? {
        didSet {
            cachedColors = nil
            needsDisplay = true
        }
    }

    /// Number of bytes per row in the hex view.
    public var bytesPerRow: Int = 16 {
        didSet {
            cachedColors = nil
            needsDisplay = true
        }
    }

    /// The total number of data rows.
    public var totalRows: Int = 0 { didSet { needsDisplay = true } }

    /// The number of visible rows in the viewport.
    public var visibleRows: Int = 0 { didSet { needsDisplay = true } }

    /// The current scroll offset (first visible row).
    public var scrollOffset: Int = 0 { didSet { needsDisplay = true } }

    /// Called when the user clicks or drags to navigate.
    public var onScrollOffsetChanged: ((Int) -> Void)?

    /// Invalidates the cached color data so it is re-rendered on next draw.
    public func invalidateCache() {
        cachedColors = nil
        needsDisplay = true
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override public var isFlipped: Bool { true }

    override public func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawBackground(in: ctx)
        drawHeatmap(in: ctx)
        drawViewport(in: ctx)
    }

    override public func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        if oldSize.height != newSize.height {
            cachedColors = nil
        }
    }

    // MARK: - Mouse Interaction

    override public func mouseDown(with event: NSEvent) {
        navigateToClick(event)
    }

    override public func mouseDragged(with event: NSEvent) {
        navigateToClick(event)
    }

    override public func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: - Private

    /// Cached per-row colors to avoid re-sampling on every scroll redraw.
    private var cachedColors: [CGColor]?
    private let inset: CGFloat = 8

    private func drawBackground(in ctx: CGContext) {
        ctx.setFillColor(NSColor.controlBackgroundColor.cgColor)
        ctx.fill(bounds)

        // Left border
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 0.5, y: 0))
        ctx.addLine(to: CGPoint(x: 0.5, y: bounds.height))
        ctx.strokePath()
    }

    private func drawHeatmap(in ctx: CGContext) {
        guard dataSource != nil, totalRows > 0 else { return }

        let rowCount = max(1, Int(bounds.height))
        if cachedColors == nil {
            cachedColors = buildColorCache(rowCount: rowCount)
        }

        guard let colors = cachedColors else { return }
        let barW = bounds.width - inset * 2
        let rowH = bounds.height / CGFloat(colors.count)

        for (idx, color) in colors.enumerated() {
            let y = CGFloat(idx) * rowH
            ctx.setFillColor(color)
            ctx.fill(CGRect(x: inset, y: y, width: barW, height: rowH + 0.5))
        }
    }

    private func buildColorCache(rowCount: Int) -> [CGColor]? {
        guard let ds = dataSource, totalRows > 0 else { return nil }
        let dataLength = ds.totalLength
        guard dataLength > 0 else { return nil }

        let isDark = effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua

        var colors = [CGColor]()
        colors.reserveCapacity(rowCount)

        // Sample multiple rows per pixel to catch sparse data.
        // For each pixel, we sample up to `maxSamplesPerPixel` evenly
        // spaced rows across the pixel's row range.
        let maxSamplesPerPixel = 8

        for py in 0..<rowCount {
            let startRow = py * totalRows / rowCount
            let endRow = max(startRow + 1, (py + 1) * totalRows / rowCount)
            let rowSpan = endRow - startRow

            // Pick evenly spaced sample rows across the range
            let sampleRowCount = min(maxSamplesPerPixel, rowSpan)
            var nonZeroBytes = 0
            var totalSampled = 0
            var byteSum: Int = 0
            var hasModified = false

            for s in 0..<sampleRowCount {
                let row = startRow + s * rowSpan / sampleRowCount
                let baseOffset = row * bytesPerRow
                for col in 0..<bytesPerRow {
                    let offset = baseOffset + col
                    guard offset < dataLength else { break }
                    guard let byte = ds.byte(at: offset) else { continue }
                    totalSampled += 1
                    byteSum += Int(byte)
                    if byte != 0x00 { nonZeroBytes += 1 }
                    if ds.isModified(at: offset) { hasModified = true }
                }
            }

            let color: CGColor
            if totalSampled == 0 {
                color = MinimapRenderer.backgroundColor(
                    isDarkMode: isDark
                ).cgColor
            } else if hasModified {
                color = MinimapRenderer.modifiedColor(
                    isDarkMode: isDark
                ).cgColor
            } else {
                let density = CGFloat(nonZeroBytes) / CGFloat(totalSampled)
                let avg = CGFloat(byteSum) / CGFloat(totalSampled) / 255.0
                color = densityColor(density, avgByte: avg, isDark: isDark)
            }
            colors.append(color)
        }
        return colors
    }

    /// Maps byte density and average value to a color.
    ///
    /// Uses a 2D mapping: density controls brightness, average byte value
    /// controls hue. Empty regions are dark, low-value data is cool
    /// (blue/purple), high-value data is warm (orange/yellow).
    private func densityColor(
        _ density: CGFloat, avgByte: CGFloat, isDark: Bool
    ) -> CGColor {
        if density < 0.001 {
            return MinimapRenderer.backgroundColor(isDarkMode: isDark).cgColor
        }
        // sqrt scale so sparse data is visible
        let brightness = min(1.0, sqrt(density))
        // Map average byte value (0–255) to hue (0.55 → 0.0 → 0.95)
        // Low bytes → blue/indigo, mid bytes → green/yellow, high → orange/red
        let hue = avgByte / 255.0 * 0.7 + 0.55
        let wrappedHue = hue.truncatingRemainder(dividingBy: 1.0)

        if isDark {
            let sat: CGFloat = 0.5 + brightness * 0.3
            let val: CGFloat = 0.2 + brightness * 0.7
            return NSColor(
                hue: wrappedHue, saturation: sat,
                brightness: val, alpha: 1
            ).cgColor
        } else {
            let sat: CGFloat = 0.3 + brightness * 0.5
            let val: CGFloat = 0.95 - brightness * 0.3
            return NSColor(
                hue: wrappedHue, saturation: sat,
                brightness: val, alpha: 1
            ).cgColor
        }
    }

    private func drawViewport(in ctx: CGContext) {
        guard totalRows > 0 else { return }

        let viewportY: CGFloat
        let viewportH: CGFloat
        let maxOffset = max(1, totalRows - visibleRows)

        if totalRows <= visibleRows {
            viewportY = 0
            viewportH = bounds.height
        } else {
            viewportH = viewportHeight()
            let scrollRange = bounds.height - viewportH
            viewportY = CGFloat(scrollOffset) / CGFloat(maxOffset) * scrollRange
        }

        let rect = CGRect(
            x: 1, y: viewportY,
            width: bounds.width - 2, height: viewportH
        )

        ctx.setFillColor(
            NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        )
        ctx.fill(rect)

        ctx.setStrokeColor(
            NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
        )
        ctx.setLineWidth(1.0)
        ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
    }

    private func viewportHeight() -> CGFloat {
        guard totalRows > 0 else { return bounds.height }
        let ratio = CGFloat(visibleRows) / CGFloat(totalRows)
        return max(20, ratio * bounds.height)
    }

    private func navigateToClick(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let maxOffset = max(0, totalRows - visibleRows)
        guard maxOffset > 0, bounds.height > 0 else { return }

        // Center the viewport on the click position
        let clickRatio = point.y / bounds.height
        let targetRow = Int(clickRatio * CGFloat(totalRows))
        let halfVisible = visibleRows / 2
        let offset = max(0, min(maxOffset, targetRow - halfVisible))

        onScrollOffsetChanged?(offset)
    }
}
