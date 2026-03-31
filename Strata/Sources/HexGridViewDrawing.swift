// HexGridViewDrawing.swift
// Strata - macOS Hex Editor

import AppKit
import CoreText

// MARK: - GridLayout

/// Layout constants for the hex grid, derived from font metrics.
public enum GridLayout {

    // MARK: - Public API

    /// Padding at the start of each column.
    public static let columnPadding: CGFloat = 8

    /// Extra space between groups of 8 bytes.
    public static let groupSpacing: CGFloat = 0

    /// Width of column separator lines.
    public static let separatorWidth: CGFloat = 1

    /// Bytes per visual group.
    public static let bytesPerGroup: Int = 8

    /// Height of the column header row.
    public static let headerHeight: CGFloat = 22

    /// Returns the character advance width for the given font.
    ///
    /// - Parameter font: A monospace font.
    /// - Returns: The character width.
    public static func charWidth(for font: NSFont) -> CGFloat {
        let attr = NSAttributedString(string: "0", attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// Returns the row height for the given font.
    ///
    /// - Parameter font: A monospace font.
    /// - Returns: The row height including padding.
    public static func rowHeight(for font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading) + 4
    }

    /// Width of the offset column (8 hex chars + padding).
    public static func offsetColumnWidth(for font: NSFont) -> CGFloat {
        charWidth(for: font) * 9 + columnPadding * 2
    }

    /// Width of the hex column for the given bytes-per-row and grouping.
    public static func hexColumnWidth(
        for font: NSFont, bytesPerRow: Int, bytesPerGroup: Int = 8
    ) -> CGFloat {
        let cw = charWidth(for: font)
        let byteWidth = cw * 3
        let groups = (bytesPerRow + bytesPerGroup - 1) / bytesPerGroup
        return byteWidth * CGFloat(bytesPerRow)
            + groupSpacing * CGFloat(max(0, groups - 1))
            + columnPadding * 2
    }

    /// Width of the ASCII column.
    public static func asciiColumnWidth(for font: NSFont, bytesPerRow: Int) -> CGFloat {
        charWidth(for: font) * CGFloat(bytesPerRow) + columnPadding * 2
    }

    /// Y position of the first data row (after the header).
    public static func dataOriginY() -> CGFloat {
        headerHeight
    }
}

// MARK: - HxD Colors

/// HxD-inspired color palette with dark mode support.
private enum StrataColors {
    static let headerBg = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.0)
    }
    static let headerText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.75, green: 0.75, blue: 0.80, alpha: 1.0)
            : NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    static let offsetText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.60, green: 0.60, blue: 0.70, alpha: 1.0)
            : NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    static let offsetBg = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.0)
    }
    static let hexText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.85, green: 0.85, blue: 0.90, alpha: 1.0)
            : NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    static let hexTextAlt = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.55, green: 0.55, blue: 0.65, alpha: 1.0)
            : NSColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0)
    }
    static let asciiBg = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.95, blue: 1.0, alpha: 1.0)
    }
    static let asciiText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.75, green: 0.75, blue: 0.85, alpha: 1.0)
            : NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    static let asciiDot = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 1.0)
            : NSColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1.0)
    }
    static let altRowBg = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
            : NSColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
    }
    static let gridLine = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
            : NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1.0)
    }
    static let modifiedByte = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
            : NSColor(red: 0.90, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    static let zeroByte = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 1.0)
            : NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
    }
}

/// Helper to check if an appearance is dark.
extension NSAppearance {
    /// Whether this appearance uses a dark color scheme.
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - Drawing Extension

extension HexGridView {

    // MARK: - Public API

    /// Main drawing entry point for the hex grid.
    public func drawGrid(in context: CGContext, dirtyRect: NSRect) {
        let font = gridFont
        let rowH = GridLayout.rowHeight(for: font)
        let offsetW = GridLayout.offsetColumnWidth(for: font)
        let hexW = GridLayout.hexColumnWidth(
            for: font, bytesPerRow: bytesPerRow, bytesPerGroup: bytesPerGroup
        )
        let cw = GridLayout.charWidth(for: font)
        let dataY = GridLayout.dataOriginY()

        // Background
        NSColor.textBackgroundColor.setFill()
        context.fill(bounds)

        // Offset column background
        StrataColors.offsetBg.setFill()
        context.fill(CGRect(x: 0, y: 0, width: offsetW, height: bounds.height))

        // ASCII column background
        StrataColors.asciiBg.setFill()
        context.fill(CGRect(x: offsetW + hexW, y: 0, width: bounds.width - offsetW - hexW, height: bounds.height))

        // Header row background
        StrataColors.headerBg.setFill()
        context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: dataY))

        drawHeader(in: context, font: font, offsetW: offsetW, hexW: hexW, cw: cw)
        drawColumnSeparators(in: context, offsetW: offsetW, hexW: hexW)

        for row in visibleRowRange {
            let displayRow = row - scrollOffset
            let y = dataY + CGFloat(displayRow) * rowH

            // Alternating row backgrounds
            if row % 2 == 1 {
                StrataColors.altRowBg.setFill()
                context.fill(CGRect(x: offsetW, y: y, width: hexW, height: rowH))
            }

            let byteOffset = row * bytesPerRow
            drawSelection(in: context, row: row, y: y, rowH: rowH, offsetW: offsetW, hexW: hexW, cw: cw)
            drawBookmarkMarker(in: context, row: row, y: y, rowH: rowH, font: font)
            drawOffsetColumn(in: context, offset: byteOffset, x: GridLayout.columnPadding, y: y, font: font)
            drawHexColumn(in: context, row: row, x: offsetW + GridLayout.columnPadding, y: y, font: font, cw: cw)
            drawASCIIColumn(
                in: context, row: row, x: offsetW + hexW + GridLayout.columnPadding, y: y, font: font, cw: cw
            )
        }

        drawCursor(in: context, rowH: rowH, offsetW: offsetW, hexW: hexW, cw: cw, dataY: dataY)
    }

    // MARK: - Private

    private func drawHeader(in ctx: CGContext, font: NSFont, offsetW: CGFloat, hexW: CGFloat, cw: CGFloat) {
        let y = font.ascender + 4
        drawText(offsetBase.headerLabel, in: ctx, at: CGPoint(x: GridLayout.columnPadding, y: y),
                 font: font, color: StrataColors.headerText)

        var xPos = offsetW + GridLayout.columnPadding
        for col in 0..<bytesPerRow {
            let label = String(format: "%02X", col)
            drawText(label, in: ctx, at: CGPoint(x: xPos, y: y), font: font, color: StrataColors.headerText)
            xPos += cw * 3
            if col > 0, (col + 1) % bytesPerGroup == 0, col + 1 < bytesPerRow {
                xPos += GridLayout.groupSpacing
            }
        }

        let asciiX = offsetW + hexW + GridLayout.columnPadding
        drawText("Decoded text", in: ctx, at: CGPoint(x: asciiX, y: y), font: font, color: StrataColors.headerText)

        // Header bottom line
        StrataColors.gridLine.setFill()
        ctx.fill(CGRect(x: 0, y: GridLayout.headerHeight - 1, width: bounds.width, height: 1))
    }

    private func drawOffsetColumn(in ctx: CGContext, offset: Int, x: CGFloat, y: CGFloat, font: NSFont) {
        let text = offsetBase.format(offset)
        drawText(text, in: ctx, at: CGPoint(x: x, y: y + font.ascender + 2), font: font, color: StrataColors.offsetText)
    }

    private func drawHexColumn(in ctx: CGContext, row: Int, x: CGFloat, y: CGFloat, font: NSFont, cw: CGFloat) {
        guard let ds = dataSource else { return }
        let baseOffset = row * bytesPerRow
        var xPos = x
        for col in 0..<bytesPerRow {
            let offset = baseOffset + col
            guard offset < ds.totalLength, let byte = ds.byte(at: offset) else { break }
            let hex: String
            let color: NSColor
            if offset == cursorPosition, let pn = pendingNibble {
                hex = String(format: "%X_", pn)
                color = StrataColors.modifiedByte
            } else {
                hex = String(format: "%02X", byte)
                if ds.isModified(at: offset) {
                    color = StrataColors.modifiedByte
                } else {
                    color = col % 2 == 0 ? StrataColors.hexText : StrataColors.hexTextAlt
                }
            }
            drawText(hex, in: ctx, at: CGPoint(x: xPos, y: y + font.ascender + 2), font: font, color: color)
            xPos += cw * 3
            if col > 0, (col + 1) % bytesPerGroup == 0, col + 1 < bytesPerRow {
                xPos += GridLayout.groupSpacing
            }
        }
    }

    private func drawASCIIColumn(in ctx: CGContext, row: Int, x: CGFloat, y: CGFloat, font: NSFont, cw: CGFloat) {
        guard let ds = dataSource else { return }
        let baseOffset = row * bytesPerRow
        for col in 0..<bytesPerRow {
            let offset = baseOffset + col
            guard offset < ds.totalLength, let byte = ds.byte(at: offset) else { break }
            let decoded = textEncoding.decode(byte)
            let color = decoded.printable ? StrataColors.asciiText : StrataColors.asciiDot
            let xPos = x + CGFloat(col) * cw
            drawText(
                decoded.character, in: ctx,
                at: CGPoint(x: xPos, y: y + font.ascender + 2),
                font: font, color: color
            )
        }
    }

    private func drawSelection(
        in ctx: CGContext, row: Int, y: CGFloat, rowH: CGFloat,
        offsetW: CGFloat, hexW: CGFloat, cw: CGFloat
    ) {
        guard let range = selectedRange else { return }
        let rowStart = row * bytesPerRow
        let rowEnd = rowStart + bytesPerRow
        let selStart = max(range.lowerBound, rowStart)
        let selEnd = min(range.upperBound, rowEnd)
        guard selStart < selEnd else { return }

        let colStart = selStart - rowStart
        let colEnd = selEnd - rowStart

        // Hex pane selection
        selectionColor.setFill()
        let hexX = offsetW + GridLayout.columnPadding + CGFloat(colStart) * cw * 3
        let hexEndX = offsetW + GridLayout.columnPadding + CGFloat(colEnd) * cw * 3 - cw
        ctx.fill(CGRect(x: hexX, y: y, width: hexEndX - hexX, height: rowH))

        // ASCII pane selection (slightly lighter)
        selectionColor.withAlphaComponent(0.4).setFill()
        let asciiBaseX = offsetW + hexW + GridLayout.columnPadding
        let asciiX = asciiBaseX + CGFloat(colStart) * cw
        let asciiEndX = asciiBaseX + CGFloat(colEnd) * cw
        ctx.fill(CGRect(x: asciiX, y: y, width: asciiEndX - asciiX, height: rowH))
    }

    private func drawColumnSeparators(in ctx: CGContext, offsetW: CGFloat, hexW: CGFloat) {
        StrataColors.gridLine.setFill()
        ctx.fill(CGRect(x: offsetW, y: 0, width: GridLayout.separatorWidth, height: bounds.height))
        ctx.fill(CGRect(x: offsetW + hexW, y: 0, width: GridLayout.separatorWidth, height: bounds.height))
    }

    private func drawCursor(
        in ctx: CGContext, rowH: CGFloat, offsetW: CGFloat, hexW: CGFloat, cw: CGFloat, dataY: CGFloat
    ) {
        guard let ds = dataSource, ds.totalLength > 0 else { return }
        guard cursorPosition >= 0, cursorPosition < ds.totalLength else { return }
        let row = cursorPosition / bytesPerRow
        guard visibleRowRange.contains(row) else { return }
        let col = cursorPosition % bytesPerRow
        let displayRow = row - scrollOffset
        let y = dataY + CGFloat(displayRow) * rowH

        // Active pane cursor
        NSColor.controlAccentColor.withAlphaComponent(0.35).setFill()
        if activePaneIsHex {
            let x = offsetW + GridLayout.columnPadding + CGFloat(col) * cw * 3
            ctx.fill(CGRect(x: x, y: y, width: cw * 2, height: rowH))
        } else {
            let x = offsetW + hexW + GridLayout.columnPadding + CGFloat(col) * cw
            ctx.fill(CGRect(x: x, y: y, width: cw, height: rowH))
        }

        // Ghost caret in inactive pane
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        if activePaneIsHex {
            let x = offsetW + hexW + GridLayout.columnPadding + CGFloat(col) * cw
            ctx.fill(CGRect(x: x, y: y, width: cw, height: rowH))
        } else {
            let x = offsetW + GridLayout.columnPadding + CGFloat(col) * cw * 3
            ctx.fill(CGRect(x: x, y: y, width: cw * 2, height: rowH))
        }
    }

    private func drawBookmarkMarker(
        in ctx: CGContext, row: Int, y: CGFloat, rowH: CGFloat, font: NSFont
    ) {
        let rowStart = row * bytesPerRow
        let rowEnd = rowStart + bytesPerRow
        for (num, offset) in bookmarks where offset >= rowStart && offset < rowEnd {
            let markerSize: CGFloat = 10
            let markerX: CGFloat = 2
            let markerY = y + (rowH - markerSize) / 2
            NSColor.systemBlue.withAlphaComponent(0.8).setFill()
            let circle = CGRect(
                x: markerX, y: markerY,
                width: markerSize, height: markerSize
            )
            ctx.fillEllipse(in: circle)
            let label = "\(num)"
            drawText(
                label, in: ctx,
                at: CGPoint(x: markerX + 2.5, y: markerY + font.ascender - 1),
                font: NSFont.monospacedSystemFont(ofSize: 8, weight: .bold),
                color: .white
            )
        }
    }

    func drawText(_ text: String, in ctx: CGContext, at point: CGPoint, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = point
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
