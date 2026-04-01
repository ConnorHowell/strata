// AppDelegate+Search.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - FindReplacePanelDelegate

extension AppDelegate: FindReplacePanelDelegate {
    func findReplacePanel(_ panel: FindReplacePanel, didSearchFor pattern: SearchPattern) {
        lastSearchPattern = pattern
        searchMatchTotal = {
            guard let ds = hexGrid.dataSource else { return 0 }
            return SearchEngine.countMatches(
                in: ds, length: ds.totalLength, pattern: pattern
            )
        }()
        showFindBar()
        performSearch(pattern: pattern)
    }

    @objc func findNextAction() {
        guard let pattern = lastSearchPattern else {
            showFindBar()
            return
        }
        let fwd = SearchPattern(
            mode: pattern.mode, data: pattern.data,
            mask: pattern.mask, direction: .forward,
            caseSensitive: pattern.caseSensitive
        )
        performSearch(pattern: fwd)
    }

    @objc func findPreviousAction() {
        guard let pattern = lastSearchPattern else {
            showFindBar()
            return
        }
        let bwd = SearchPattern(
            mode: pattern.mode, data: pattern.data,
            mask: pattern.mask, direction: .backward,
            caseSensitive: pattern.caseSensitive
        )
        performSearch(pattern: bwd)
    }

    func performSearch(pattern: SearchPattern) {
        guard let ds = hexGrid.dataSource else { return }
        let len = ds.totalLength
        guard len > 0, !pattern.data.isEmpty else { return }
        let patLen = pattern.data.count
        let start: Int
        switch pattern.direction {
        case .forward:
            start = hexGrid.cursorPosition + 1
        case .backward:
            start = hexGrid.cursorPosition - 1
        case .all:
            start = 0
        }

        let found = SearchEngine.wrappingSearch(
            in: ds, length: len, pattern: pattern, from: start
        )
        if let pos = found {
            hexGrid.selectedRange = pos..<(pos + patLen)
            hexGrid.cursorPosition = pos
            hexGrid.scrollToOffset(pos)
            hexGrid.needsDisplay = true
            updateStatusBar()
            updateDataInspector()
            if !findBar.isHidden {
                searchMatchIndex = SearchEngine.matchIndex(
                    in: ds, length: len, pattern: pattern, at: pos
                )
                let term = searchTermDescription(pattern)
                findBar.update(
                    term: term,
                    current: searchMatchIndex,
                    total: searchMatchTotal
                )
            }
        } else {
            if findBar.isHidden {
                showNotFoundAlert()
            } else {
                searchMatchIndex = 0
                searchMatchTotal = 0
                findBar.update(
                    term: searchTermDescription(pattern),
                    current: 0,
                    total: 0
                )
            }
        }
    }

    func searchTermDescription(_ pattern: SearchPattern) -> String {
        switch pattern.mode {
        case .textString:
            return String(data: pattern.data, encoding: .utf8) ?? "?"
        case .hexValues:
            let hex = pattern.data.map { String(format: "%02X", $0) }
            let joined = hex.prefix(6).joined(separator: " ")
            return hex.count > 6 ? joined + "..." : joined
        case .integerNumber:
            return "int"
        case .floatingPoint:
            return "float"
        }
    }

    func findReplacePanel(_ panel: FindReplacePanel, didReplaceWith data: Data) {
        guard let range = hexGrid.selectedRange else { return }
        hexGrid.dataSource?.delete(range: range)
        hexGrid.dataSource?.insert(at: range.lowerBound, bytes: data)
        hexGrid.selectedRange = nil
        hexGrid.needsDisplay = true
    }

    func findReplacePanelDidReplaceAll(
        _ panel: FindReplacePanel, search: SearchPattern, replacement: Data
    ) {
        guard let ds = hexGrid.dataSource else { return }
        var count = 0
        var offset = 0
        while offset <= ds.totalLength - search.data.count {
            if let pos = SearchEngine.linearSearch(
                in: ds, length: ds.totalLength, pattern: search, from: offset
            ) {
                ds.delete(range: pos..<(pos + search.data.count))
                ds.insert(at: pos, bytes: replacement)
                offset = pos + replacement.count
                count += 1
            } else {
                break
            }
        }
        hexGrid.selectedRange = nil
        hexGrid.needsDisplay = true
        guard let win = window else { return }
        let alert = NSAlert()
        alert.messageText = "\(count) replacement(s) made."
        alert.alertStyle = .informational
        alert.beginSheetModal(for: win)
    }

    func showNotFoundAlert() {
        guard let win = window else { return }
        let alert = NSAlert()
        alert.messageText = "Search term not found."
        alert.informativeText = "The specified data was not found in the file."
        alert.alertStyle = .informational
        alert.beginSheetModal(for: win)
    }
}

// MARK: - FindBarDelegate

extension AppDelegate: FindBarDelegate {
    func findBarDidRequestNext(_ bar: FindBar) {
        findNextAction()
    }

    func findBarDidRequestPrevious(_ bar: FindBar) {
        findPreviousAction()
    }

    func findBarDidDismiss(_ bar: FindBar) {
        hideFindBar()
        lastSearchPattern = nil
        searchMatchIndex = 0
        hexGrid.selectedRange = nil
        hexGrid.needsDisplay = true
    }
}
