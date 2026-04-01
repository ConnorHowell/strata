// MinimapRenderer.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - ByteClass

/// Classification of a byte value for minimap coloring.
enum ByteClass: CaseIterable {
    case null
    case asciiPrintable
    case asciiControl
    case highByte

    /// Classifies a single byte value.
    ///
    /// - Parameter byte: The byte to classify.
    /// - Returns: The byte class.
    static func classify(_ byte: UInt8) -> ByteClass {
        switch byte {
        case 0x00:
            return .null
        case 0x20...0x7E:
            return .asciiPrintable
        case 0x01...0x1F, 0x7F:
            return .asciiControl
        default:
            return .highByte
        }
    }
}

// MARK: - MinimapRenderer

/// Renders a byte-class heatmap bitmap for the minimap.
enum MinimapRenderer {

    // MARK: - Public API

    /// Color components for a single pixel.
    struct PixelColor {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
        var alpha: UInt8

        /// Converts to a `CGColor` for use with Core Graphics fill commands.
        var cgColor: CGColor {
            CGColor(
                red: CGFloat(red) / 255.0,
                green: CGFloat(green) / 255.0,
                blue: CGFloat(blue) / 255.0,
                alpha: CGFloat(alpha) / 255.0
            )
        }
    }

    /// Renders a bitmap representing the byte-class distribution of the data.
    ///
    /// Uses CGContext fill commands for reliable rendering (no raw pixel math).
    ///
    /// - Parameters:
    ///   - dataSource: The piece table to sample bytes from.
    ///   - totalRows: The total number of data rows.
    ///   - bytesPerRow: Bytes per row in the hex view.
    ///   - width: Bitmap width in pixels.
    ///   - height: Bitmap height in pixels.
    ///   - isDarkMode: Whether dark mode is active.
    /// - Returns: A rendered `CGImage`, or `nil` on failure.
    static func renderBitmap(
        dataSource: PieceTable,
        totalRows: Int,
        bytesPerRow: Int,
        width: Int,
        height: Int,
        isDarkMode: Bool
    ) -> CGImage? {
        guard totalRows > 0, width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        let dataLength = dataSource.totalLength
        guard dataLength > 0 else { return nil }

        let bg = backgroundColor(isDarkMode: isDarkMode)
        ctx.setFillColor(bg.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // CG bitmap: y=0 is bottom. We want py=0 (start of file) at top.
        // So py=0 maps to CG y = height-1, py=height-1 maps to CG y = 0.
        for py in 0..<height {
            let startRow = py * totalRows / height
            let endRow = max(startRow + 1, (py + 1) * totalRows / height)
            let midRow = (startRow + endRow) / 2

            let baseOffset = midRow * bytesPerRow
            var counts = [Int](repeating: 0, count: ByteClass.allCases.count)
            var modifiedCount = 0
            var sampleCount = 0

            for col in 0..<bytesPerRow {
                let offset = baseOffset + col
                guard offset < dataLength else { break }
                guard let byte = dataSource.byte(at: offset) else { continue }
                counts[classIndex(ByteClass.classify(byte))] += 1
                if dataSource.isModified(at: offset) { modifiedCount += 1 }
                sampleCount += 1
            }

            guard sampleCount > 0 else { continue }

            let color: PixelColor
            if modifiedCount > sampleCount / 2 {
                color = modifiedColor(isDarkMode: isDarkMode)
            } else {
                color = dominantColor(counts: counts, isDarkMode: isDarkMode)
            }

            // py=0 is file start. In CG bitmap, y=0 is bottom.
            // The draw call in MinimapView applies a flip, so write py=0
            // to CG y=height-1 (top of bitmap) so it ends at view top.
            let cgY = CGFloat(height - 1 - py)
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: 0, y: cgY, width: CGFloat(width), height: 1.5))
        }

        return ctx.makeImage()
    }

    // MARK: - Internal

    static func classIndex(_ cls: ByteClass) -> Int {
        switch cls {
        case .null: return 0
        case .asciiPrintable: return 1
        case .asciiControl: return 2
        case .highByte: return 3
        }
    }

    static func dominantColor(counts: [Int], isDarkMode: Bool) -> PixelColor {
        var maxIdx = 0
        for i in 1..<counts.count where counts[i] > counts[maxIdx] {
            maxIdx = i
        }
        return colorForClass(maxIdx, isDarkMode: isDarkMode)
    }

    static func colorForClass(_ index: Int, isDarkMode: Bool) -> PixelColor {
        if isDarkMode {
            switch index {
            case 0: return PixelColor(red: 60, green: 60, blue: 60, alpha: 255)       // null — dark gray
            case 1: return PixelColor(red: 80, green: 140, blue: 220, alpha: 255)      // printable — blue
            case 2: return PixelColor(red: 80, green: 180, blue: 100, alpha: 255)      // control — green
            default: return PixelColor(red: 220, green: 150, blue: 60, alpha: 255)     // high — orange
            }
        } else {
            switch index {
            case 0: return PixelColor(red: 200, green: 200, blue: 200, alpha: 255)     // null — light gray
            case 1: return PixelColor(red: 60, green: 120, blue: 210, alpha: 255)      // printable — blue
            case 2: return PixelColor(red: 60, green: 160, blue: 80, alpha: 255)       // control — green
            default: return PixelColor(red: 210, green: 130, blue: 40, alpha: 255)     // high — orange
            }
        }
    }

    static func modifiedColor(isDarkMode: Bool) -> PixelColor {
        if isDarkMode {
            return PixelColor(red: 220, green: 70, blue: 70, alpha: 255)
        } else {
            return PixelColor(red: 200, green: 50, blue: 50, alpha: 255)
        }
    }

    static func backgroundColor(isDarkMode: Bool) -> PixelColor {
        if isDarkMode {
            return PixelColor(red: 30, green: 30, blue: 30, alpha: 255)
        } else {
            return PixelColor(red: 245, green: 245, blue: 245, alpha: 255)
        }
    }
}
