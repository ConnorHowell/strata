// FindReplacePanel.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - SearchMode

/// The search input mode corresponding to HxD tabs.
public enum SearchMode: Int {
    /// Text string search with encoding options.
    case textString = 0
    /// Raw hex byte values.
    case hexValues = 1
    /// Integer number with bit-width and byte order.
    case integerNumber = 2
    /// Floating point number with type selection.
    case floatingPoint = 3
}

// MARK: - SearchDirection

/// The direction to search.
public enum SearchDirection {
    /// Search from current position toward end.
    case forward
    /// Search from current position toward start.
    case backward
    /// Search the entire file.
    case all
}

// MARK: - SearchPattern

/// A parsed search pattern ready for byte-level matching.
public struct SearchPattern {
    /// The search mode that produced this pattern.
    public let mode: SearchMode
    /// The target bytes to search for.
    public let data: Data
    /// Optional wildcard mask. `nil` means match all bytes exactly.
    public let mask: Data?
    /// The direction to search.
    public let direction: SearchDirection
}

// MARK: - FindReplacePanelDelegate

/// Delegate for find/replace actions.
public protocol FindReplacePanelDelegate: AnyObject {
    /// Called when the user initiates a search.
    func findReplacePanel(_ panel: FindReplacePanel, didSearchFor pattern: SearchPattern)
    /// Called when the user initiates a single replacement.
    func findReplacePanel(_ panel: FindReplacePanel, didReplaceWith data: Data)
    /// Called when the user initiates replace all.
    func findReplacePanelDidReplaceAll(_ panel: FindReplacePanel, search: SearchPattern, replacement: Data)
}

// MARK: - FindReplacePanel

/// HxD-style Find/Replace dialog presented as a modal window with 4 tabs.
public final class FindReplacePanel: NSView {

    // MARK: - Public API

    /// The delegate for search and replace callbacks.
    public weak var delegate: FindReplacePanelDelegate?

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Parses a hex string like "FF 00 AB" into data bytes.
    public static func parseHexPattern(_ string: String) -> Data? {
        let cleaned = string.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0, !cleaned.isEmpty else { return nil }
        var bytes: [UInt8] = []
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            let next = cleaned.index(idx, offsetBy: 2)
            guard let byte = UInt8(cleaned[idx..<next], radix: 16) else { return nil }
            bytes.append(byte)
            idx = next
        }
        return Data(bytes)
    }

    /// Parses a hex string with `??` wildcards into data and mask.
    public static func parseWildcardPattern(_ string: String) -> (data: Data, mask: Data)? {
        let tokens = string.split(separator: " ")
        guard !tokens.isEmpty else { return nil }
        var bytes: [UInt8] = []
        var mask: [UInt8] = []
        for token in tokens {
            if token == "??" {
                bytes.append(0x00)
                mask.append(0x00)
            } else if token.count == 2, let byte = UInt8(token, radix: 16) {
                bytes.append(byte)
                mask.append(0xFF)
            } else {
                return nil
            }
        }
        return (data: Data(bytes), mask: Data(mask))
    }

    /// Shows the Find dialog as a modal window.
    public func showFindDialog(relativeTo parentWindow: NSWindow) {
        activeDialog = FindReplaceWindowController(isReplace: false, delegate: delegate)
        guard let win = activeDialog?.window else { return }
        parentWindow.beginSheet(win) { [weak self] _ in self?.activeDialog = nil }
    }

    /// Shows the Replace dialog as a modal window.
    public func showReplaceDialog(relativeTo parentWindow: NSWindow) {
        activeDialog = FindReplaceWindowController(isReplace: true, delegate: delegate)
        guard let win = activeDialog?.window else { return }
        parentWindow.beginSheet(win) { [weak self] _ in self?.activeDialog = nil }
    }

    // MARK: - Private

    private var activeDialog: FindReplaceWindowController?
}
