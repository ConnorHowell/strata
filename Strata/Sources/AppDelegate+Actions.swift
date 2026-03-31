// AppDelegate+Actions.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - Menu Action Handlers

extension AppDelegate {

    @objc func newFileAction() { sessionManager.newSession(); refreshUI() }

    @objc func openFileAction() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try sessionManager.openFile(at: url)
            refreshUI()
        } catch {
            showError(error)
        }
    }

    @objc func saveFileAction() {
        guard let session = sessionManager.activeSession else { return }
        if session.fileURL == nil { saveFileAsAction(); return }
        do { try session.save() } catch { showError(error) }
    }

    @objc func saveFileAsAction() {
        let panel = NSSavePanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try sessionManager.activeSession?.save(to: url)
            refreshUI()
        } catch { showError(error) }
    }

    @objc func closeTabAction() {
        sessionManager.closeSession(at: sessionManager.activeSessionIndex)
        refreshUI()
    }

    @objc func undoAction() { hexGrid.handleKeyAction(.undo); updateStatusBar() }
    @objc func redoAction() { hexGrid.handleKeyAction(.redo); updateStatusBar() }
    @objc func cutAction() { hexGrid.handleCut() }
    @objc func copyAction() { hexGrid.handleCopy() }
    @objc func pasteAction() { hexGrid.handlePaste() }
    @objc func selectAllAction() { hexGrid.handleSelectAll() }

    @objc func showFindAction() {
        guard let win = window else { return }
        findPanel.showFindDialog(relativeTo: win)
    }

    @objc func showReplaceAction() {
        guard let win = window else { return }
        findPanel.showReplaceDialog(relativeTo: win)
    }

    @objc func showGoToAction() {
        let sheet = GoToOffsetSheet()
        sheet.offsetDelegate = self
        sheet.maxOffset = sessionManager.activeSession?.pieceTable.totalLength ?? 0
        guard let win = window else { return }
        let hostVC = NSViewController()
        hostVC.view = win.contentView ?? NSView()
        hostVC.presentAsSheet(sheet)
    }

    @objc func toggleChecksumPanelAction() { isChecksumPanelVisible.toggle() }
    @objc func toggleInsertModeAction() { hexGrid.isInsertMode.toggle(); updateStatusBar() }
    @objc func compareToolAction() {}

    @objc func importIntelHexAction() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let records = try IntelHex.parse(content)
            let data = IntelHex.toData(records)
            let session = sessionManager.newSession()
            session.pieceTable.insert(at: 0, bytes: data)
            refreshUI()
        } catch { showError(error) }
    }

    @objc func importSRecordAction() {
        let panel = NSOpenPanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let records = try SRecord.parse(content)
            let data = SRecord.toData(records)
            let session = sessionManager.newSession()
            session.pieceTable.insert(at: 0, bytes: data)
            refreshUI()
        } catch { showError(error) }
    }

    @objc func exportIntelHexAction() {
        guard let session = sessionManager.activeSession else { return }
        let panel = NSSavePanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = session.pieceTable.bytes(in: 0..<session.pieceTable.totalLength)
        let hex = IntelHex.fromData(data)
        do { try hex.write(to: url, atomically: true, encoding: .utf8) } catch { showError(error) }
    }

    @objc func exportSRecordAction() {
        guard let session = sessionManager.activeSession else { return }
        let panel = NSSavePanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = session.pieceTable.bytes(in: 0..<session.pieceTable.totalLength)
        let srec = SRecord.fromData(data)
        do { try srec.write(to: url, atomically: true, encoding: .utf8) } catch { showError(error) }
    }

    func showError(_ error: Error) {
        guard let win = window else { return }
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: win)
    }
}

// MARK: - Delegate Conformances

extension AppDelegate: SessionManagerDelegate {
    func sessionManagerDidChangeActive(_ manager: SessionManager) { refreshUI() }
    func sessionManagerDidAddSession(_ manager: SessionManager, at index: Int) { refreshUI() }
    func sessionManagerDidRemoveSession(_ manager: SessionManager, at index: Int) { refreshUI() }
}

extension AppDelegate: HexGridViewDelegate {
    func hexGridView(_ view: HexGridView, didEditByteAt offset: Int, value: UInt8) {
        updateStatusBar()
        updateDataInspector()
    }

    func hexGridView(_ view: HexGridView, didChangeSelection range: Range<Int>?) {
        updateStatusBar()
        updateDataInspector()
    }
}

extension AppDelegate: TabBarDelegate {
    func tabBar(_ tabBar: TabBar, didSelectTabAt index: Int) {
        sessionManager.setActive(index: index)
    }

    func tabBar(_ tabBar: TabBar, didCloseTabAt index: Int) {
        sessionManager.closeSession(at: index)
    }
}

extension AppDelegate: FindReplacePanelDelegate {
    func findReplacePanel(_ panel: FindReplacePanel, didSearchFor pattern: SearchPattern) {
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

        let found = searchBytes(in: ds, length: len, pattern: pattern, from: start)
        if let pos = found {
            hexGrid.selectedRange = pos..<(pos + patLen)
            hexGrid.cursorPosition = pos
            hexGrid.scrollToOffset(pos)
            hexGrid.needsDisplay = true
            updateStatusBar()
            updateDataInspector()
        } else {
            showNotFoundAlert()
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
            if let pos = searchBytes(in: ds, length: ds.totalLength, pattern: search, from: offset) {
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

    private func searchBytes(
        in ds: PieceTable, length len: Int, pattern: SearchPattern, from start: Int
    ) -> Int? {
        let patLen = pattern.data.count
        guard patLen <= len else { return nil }
        for i in 0..<len {
            let pos: Int
            switch pattern.direction {
            case .backward:
                pos = ((start - i) % len + len) % len
            default:
                pos = (start + i) % len
            }
            guard pos + patLen <= len else { continue }
            var matched = true
            for j in 0..<patLen {
                guard let byte = ds.byte(at: pos + j) else { matched = false; break }
                if let mask = pattern.mask {
                    if byte & mask[j] != pattern.data[j] & mask[j] { matched = false; break }
                } else if byte != pattern.data[j] {
                    matched = false; break
                }
            }
            if matched { return pos }
        }
        return nil
    }

    private func showNotFoundAlert() {
        guard let win = window else { return }
        let alert = NSAlert()
        alert.messageText = "Search term not found."
        alert.informativeText = "The specified data was not found in the file."
        alert.alertStyle = .informational
        alert.beginSheetModal(for: win)
    }
}

extension AppDelegate: NSSplitViewDelegate {
    func splitView(
        _ splitView: NSSplitView,
        constrainMinCoordinate proposedMinimumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        max(proposedMinimumPosition, 400)
    }

    func splitView(
        _ splitView: NSSplitView,
        constrainMaxCoordinate proposedMaximumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        splitView.bounds.width - 120
    }

    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        // Keep inspector fixed width when window resizes
        view !== dataInspector
    }
}

extension AppDelegate: GoToOffsetDelegate {
    func goToOffset(_ offset: Int) {
        hexGrid.scrollToOffset(offset)
        hexGrid.cursorPosition = offset
        updateStatusBar()
        updateDataInspector()
    }
}
