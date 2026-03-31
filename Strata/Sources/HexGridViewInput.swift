// HexGridViewInput.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - Input Handling Extension

extension HexGridView {

    // MARK: - Public API

    /// Dispatches a key action to the appropriate handler.
    ///
    /// - Parameter action: The action to perform.
    public func handleKeyAction(_ action: KeyAction) {
        switch action {
        case .togglePaneFocus:
            togglePane()
        case .toggleInsertMode:
            isInsertMode.toggle()
            needsDisplay = true
        case .pageUp, .pageDown, .home, .end, .documentStart, .documentEnd:
            handleNavigation(action)
        case .copy:
            handleCopy()
        case .cut:
            handleCut()
        case .paste:
            handlePaste()
        case .selectAll:
            handleSelectAll()
        case .undo:
            dataSource?.undoManager.undo()
            needsDisplay = true
        case .redo:
            dataSource?.undoManager.redo()
            needsDisplay = true
        default:
            break
        }
    }

    /// Handles hex digit input in the hex pane.
    ///
    /// Processes nibble-by-nibble: the first hex char sets the high nibble,
    /// the second sets the low nibble and advances the cursor.
    ///
    /// - Parameter char: The typed character.
    public func handleHexInput(_ char: Character) {
        guard let nibble = hexValue(of: char) else { return }
        guard let ds = dataSource, cursorPosition < ds.totalLength || isInsertMode else { return }

        if let high = pendingNibble {
            let value = (high << 4) | nibble
            if isInsertMode {
                ds.insert(at: cursorPosition, bytes: Data([value]))
            } else {
                ds.overwrite(at: cursorPosition, bytes: Data([value]))
            }
            delegate?.hexGridView(self, didEditByteAt: cursorPosition, value: value)
            pendingNibble = nil
            cursorPosition = min(cursorPosition + 1, ds.totalLength - 1)
        } else {
            pendingNibble = nibble
        }
        needsDisplay = true
    }

    /// Handles ASCII input in the ASCII pane.
    ///
    /// - Parameter char: The typed ASCII character.
    public func handleASCIIInput(_ char: Character) {
        guard let ascii = char.asciiValue else { return }
        guard let ds = dataSource else { return }

        if isInsertMode {
            ds.insert(at: cursorPosition, bytes: Data([ascii]))
        } else {
            guard cursorPosition < ds.totalLength else { return }
            ds.overwrite(at: cursorPosition, bytes: Data([ascii]))
        }
        delegate?.hexGridView(self, didEditByteAt: cursorPosition, value: ascii)
        cursorPosition = min(cursorPosition + 1, max(0, ds.totalLength - 1))
        pendingNibble = nil
        needsDisplay = true
    }

    /// Handles navigation key actions.
    ///
    /// - Parameter action: The navigation action.
    public func handleNavigation(_ action: KeyAction) {
        guard let ds = dataSource else { return }
        let rowH = GridLayout.rowHeight(for: gridFont)
        guard rowH > 0 else { return }
        let visibleRows = Int(bounds.height / rowH)

        switch action {
        case .pageUp:
            scrollOffset = max(0, scrollOffset - visibleRows)
            cursorPosition = max(0, cursorPosition - visibleRows * bytesPerRow)
        case .pageDown:
            scrollOffset = min(max(0, totalRows - visibleRows), scrollOffset + visibleRows)
            cursorPosition = min(ds.totalLength - 1, cursorPosition + visibleRows * bytesPerRow)
        case .home:
            cursorPosition = (cursorPosition / bytesPerRow) * bytesPerRow
        case .end:
            cursorPosition = min((cursorPosition / bytesPerRow + 1) * bytesPerRow - 1, ds.totalLength - 1)
        case .documentStart:
            scrollOffset = 0
            cursorPosition = 0
        case .documentEnd:
            cursorPosition = max(0, ds.totalLength - 1)
            scrollOffset = max(0, totalRows - visibleRows)
        default:
            break
        }
        needsDisplay = true
    }

    /// Converts a mouse click to a byte offset and updates selection.
    ///
    /// - Parameters:
    ///   - point: The click location in view coordinates.
    ///   - extending: Whether to extend the current selection.
    public func handleMouseSelection(at point: NSPoint, extending: Bool) {
        guard let offset = hitTestByte(at: point) else { return }
        if extending, let existing = selectedRange {
            let newStart = min(existing.lowerBound, offset)
            let newEnd = max(existing.upperBound, offset + 1)
            selectedRange = newStart..<newEnd
        } else {
            selectedRange = nil
            cursorPosition = offset
        }
        pendingNibble = nil
        needsDisplay = true
    }

    /// Determines which byte offset corresponds to a point in the view.
    ///
    /// - Parameter point: The point in view coordinates.
    /// - Returns: The byte offset, or `nil` if the point is outside the grid.
    public func hitTestByte(at point: NSPoint) -> Int? {
        guard let ds = dataSource else { return nil }
        let rowH = GridLayout.rowHeight(for: gridFont)
        let dataY = GridLayout.dataOriginY()
        guard rowH > 0, point.y >= dataY else { return nil }
        let row = scrollOffset + Int((point.y - dataY) / rowH)
        guard row >= 0, row < totalRows else { return nil }

        let offsetW = GridLayout.offsetColumnWidth(for: gridFont)
        let hexW = GridLayout.hexColumnWidth(for: gridFont, bytesPerRow: bytesPerRow)
        let cw = GridLayout.charWidth(for: gridFont)

        let x = point.x
        var col: Int?
        if x >= offsetW, x < offsetW + hexW {
            let relX = x - offsetW - GridLayout.columnPadding
            let approxCol = Int(relX / (cw * 3))
            col = max(0, min(approxCol, bytesPerRow - 1))
            activePaneIsHex = true
        } else if x >= offsetW + hexW {
            let relX = x - offsetW - hexW - GridLayout.columnPadding
            let approxCol = Int(relX / cw)
            col = max(0, min(approxCol, bytesPerRow - 1))
            activePaneIsHex = false
        }

        guard let c = col else { return nil }
        let offset = row * bytesPerRow + c
        return offset < ds.totalLength ? offset : nil
    }

    /// Copies the selected bytes to the clipboard as hex string.
    public func handleCopy() {
        guard let ds = dataSource, let range = selectedRange else { return }
        let data = ds.bytes(in: range)
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }

    /// Cuts the selected bytes to the clipboard.
    public func handleCut() {
        handleCopy()
        guard let ds = dataSource, let range = selectedRange else { return }
        ds.delete(range: range)
        selectedRange = nil
        cursorPosition = min(range.lowerBound, max(0, ds.totalLength - 1))
        needsDisplay = true
    }

    /// Pastes hex bytes from the clipboard.
    public func handlePaste() {
        guard let ds = dataSource,
              let hex = NSPasteboard.general.string(forType: .string) else { return }
        let bytes = parseHexString(hex)
        guard !bytes.isEmpty else { return }
        let data = Data(bytes)
        if isInsertMode {
            ds.insert(at: cursorPosition, bytes: data)
        } else {
            ds.overwrite(at: cursorPosition, bytes: data)
        }
        needsDisplay = true
    }

    /// Selects all bytes in the data source.
    public func handleSelectAll() {
        guard let ds = dataSource, ds.totalLength > 0 else { return }
        selectedRange = 0..<ds.totalLength
    }

    // MARK: - Private

    private func hexValue(of char: Character) -> UInt8? {
        switch char {
        case "0"..."9": return UInt8(char.asciiValue! - Character("0").asciiValue!)
        case "a"..."f": return UInt8(char.asciiValue! - Character("a").asciiValue!) + 10
        case "A"..."F": return UInt8(char.asciiValue! - Character("A").asciiValue!) + 10
        default: return nil
        }
    }

    private func parseHexString(_ hex: String) -> [UInt8] {
        let cleaned = hex.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0 else { return [] }
        var bytes: [UInt8] = []
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            guard let end = cleaned.index(idx, offsetBy: 2, limitedBy: cleaned.endIndex),
                  let byte = UInt8(String(cleaned[idx..<end]), radix: 16) else {
                return []
            }
            bytes.append(byte)
            idx = end
        }
        return bytes
    }
}
