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
            addToRecentFiles(url)
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

    func showFindBar() {
        guard findBar.isHidden else { return }
        findBar.isHidden = false
        splitViewTopConstraint?.isActive = false
        splitViewTopConstraint = splitView.topAnchor.constraint(
            equalTo: findBar.bottomAnchor
        )
        splitViewTopConstraint?.isActive = true
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    func hideFindBar() {
        guard !findBar.isHidden else { return }
        findBar.isHidden = true
        splitViewTopConstraint?.isActive = false
        splitViewTopConstraint = splitView.topAnchor.constraint(
            equalTo: tabBar.bottomAnchor
        )
        splitViewTopConstraint?.isActive = true
        window?.contentView?.layoutSubtreeIfNeeded()
        window?.makeFirstResponder(hexGrid)
    }

    @objc func showSelectBlockAction() {
        let sheet = SelectBlockSheet()
        sheet.blockDelegate = self
        sheet.maxOffset = sessionManager.activeSession?.pieceTable.totalLength ?? 0
        sheet.initialStart = hexGrid.cursorPosition
        guard let win = window else { return }
        let hostVC = NSViewController()
        hostVC.view = win.contentView ?? NSView()
        hostVC.presentAsSheet(sheet)
    }

    @objc func showGoToAction() {
        let sheet = GoToOffsetSheet()
        sheet.offsetDelegate = self
        sheet.maxOffset = sessionManager.activeSession?.pieceTable.totalLength ?? 0
        sheet.currentOffset = hexGrid.cursorPosition
        guard let win = window else { return }
        let hostVC = NSViewController()
        hostVC.view = win.contentView ?? NSView()
        hostVC.presentAsSheet(sheet)
    }

    @objc func toggleChecksumPanelAction() { isChecksumPanelVisible.toggle() }
    @objc func toggleInsertModeAction() { hexGrid.isInsertMode.toggle(); updateStatusBar() }

    @objc func toggleMinimapAction() {
        isMinimapVisible.toggle()
        minimapView.isHidden = !isMinimapVisible
        if isMinimapVisible {
            let w = splitView.bounds.width
            splitView.setPosition(w - 220 - 80, ofDividerAt: 0)
            splitView.setPosition(w - 220, ofDividerAt: 1)
        }
        splitView.adjustSubviews()
    }
    @objc func compareToolAction() {
        guard let session = sessionManager.activeSession else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.message = "Select a file to compare with the current document."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let otherData = try Data(contentsOf: url, options: .mappedIfSafe)
            let currentLen = session.pieceTable.totalLength
            let currentData = session.pieceTable.bytes(in: 0..<currentLen)
            let diffView = DiffView(
                frame: NSRect(x: 0, y: 0, width: 900, height: 600)
            )
            diffView.setFileNames(
                left: session.fileName,
                right: url.lastPathComponent
            )
            diffView.compare(left: currentData, right: otherData)

            let diffWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            diffWindow.isReleasedWhenClosed = false
            diffWindow.title = "Compare: \(session.fileName) ↔ \(url.lastPathComponent)"
            diffWindow.contentView = diffView
            diffWindow.center()
            diffWindow.makeKeyAndOrderFront(nil)
            retainAuxiliaryWindow(diffWindow)
        } catch {
            showError(error)
        }
    }

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

    @objc func setOffsetBase(_ sender: NSMenuItem) {
        guard let base = sender.representedObject as? OffsetBase else { return }
        hexGrid.offsetBase = base
    }

    @objc func setTextEncoding(_ sender: NSMenuItem) {
        guard let enc = sender.representedObject as? TextEncoding else { return }
        hexGrid.textEncoding = enc
    }

    @objc func setBytesPerRow(_ sender: NSMenuItem) {
        hexGrid.bytesPerRow = sender.tag
    }

    @objc func setByteGrouping(_ sender: NSMenuItem) {
        hexGrid.bytesPerGroup = sender.tag
    }

    @objc func fillSelectionAction() {
        guard hexGrid.selectedRange != nil else {
            guard let win = window else { return }
            let alert = NSAlert()
            alert.messageText = "No Selection"
            alert.informativeText = "Select a range of bytes first."
            alert.alertStyle = .informational
            alert.beginSheetModal(for: win)
            return
        }
        guard let win = window else { return }
        let alert = NSAlert()
        alert.messageText = "Fill Selection"
        alert.informativeText = "Enter a hex byte value (e.g. 00, FF):"
        alert.addButton(withTitle: "Fill")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "00"
        alert.accessoryView = input
        alert.beginSheetModal(for: win) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let text = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard let byte = UInt8(text, radix: 16) else { return }
            self?.hexGrid.handleFillSelection(with: byte)
            self?.updateStatusBar()
        }
    }

    @objc func byteStatisticsAction() {
        guard let session = sessionManager.activeSession else { return }
        let len = session.pieceTable.totalLength
        guard len > 0 else { return }
        let data = session.pieceTable.bytes(in: 0..<len)
        let panel = ByteStatisticsPanel(data: data)
        let statsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        statsWindow.isReleasedWhenClosed = false
        statsWindow.title = "Byte Statistics — \(session.fileName)"
        statsWindow.contentView = panel
        statsWindow.center()
        statsWindow.makeKeyAndOrderFront(nil)
        retainAuxiliaryWindow(statsWindow)
    }

    @objc func concatenateFilesAction() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.message = "Select files to concatenate (in order)."
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        var combined = Data()
        for url in panel.urls {
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                combined.append(data)
            } catch {
                showError(error)
                return
            }
        }
        let session = sessionManager.newSession()
        session.pieceTable.insert(at: 0, bytes: combined)
        refreshUI()
    }

    @objc func splitFileAction() {
        guard let session = sessionManager.activeSession else { return }
        let len = session.pieceTable.totalLength
        guard len > 0, let win = window else { return }
        let alert = NSAlert()
        alert.messageText = "Split File"
        alert.informativeText = "Enter chunk size in bytes (decimal):"
        alert.addButton(withTitle: "Split")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "1024"
        alert.accessoryView = input
        alert.beginSheetModal(for: win) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            guard let self,
                  let chunkSize = Int(input.stringValue),
                  chunkSize > 0 else { return }
            let dirPanel = NSOpenPanel()
            dirPanel.canChooseDirectories = true
            dirPanel.canChooseFiles = false
            dirPanel.canCreateDirectories = true
            dirPanel.message = "Choose output directory for split files."
            guard dirPanel.runModal() == .OK, let dir = dirPanel.url else { return }
            let data = session.pieceTable.bytes(in: 0..<len)
            var partNum = 0
            var offset = 0
            while offset < data.count {
                let end = min(offset + chunkSize, data.count)
                let chunk = data[offset..<end]
                let name = String(
                    format: "%@.%03d",
                    session.fileName, partNum
                )
                let fileURL = dir.appendingPathComponent(name)
                do {
                    try Data(chunk).write(to: fileURL, options: .atomic)
                } catch {
                    self.showError(error)
                    return
                }
                partNum += 1
                offset = end
            }
            let done = NSAlert()
            done.messageText = "Split complete."
            done.informativeText = "\(partNum) files created."
            done.alertStyle = .informational
            done.beginSheetModal(for: win)
        }
    }

    @objc func openRecentFile(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx >= 0, idx < recentFileURLs.count else { return }
        let url = recentFileURLs[idx]
        do {
            try sessionManager.openFile(at: url)
            refreshUI()
        } catch {
            showError(error)
        }
    }

    @objc func clearRecentFiles() {
        recentFileURLs.removeAll()
        UserDefaults.standard.removeObject(forKey: "recentFiles")
        setupMainMenu()
    }

    func addToRecentFiles(_ url: URL) {
        recentFileURLs.removeAll { $0 == url }
        recentFileURLs.insert(url, at: 0)
        if recentFileURLs.count > AppDelegate.maxRecentFiles {
            recentFileURLs = Array(recentFileURLs.prefix(AppDelegate.maxRecentFiles))
        }
        let paths = recentFileURLs.map(\.path)
        UserDefaults.standard.set(paths, forKey: "recentFiles")
        setupMainMenu()
    }

    func loadRecentFiles() {
        guard let paths = UserDefaults.standard.stringArray(forKey: "recentFiles") else {
            return
        }
        recentFileURLs = paths.map { URL(fileURLWithPath: $0) }
    }

    /// Retains an auxiliary window and releases it when closed.
    func retainAuxiliaryWindow(_ win: NSWindow) {
        auxiliaryWindows.append(win)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: win,
            queue: .main
        ) { [weak self] notification in
            guard let closed = notification.object as? NSWindow else { return }
            self?.auxiliaryWindows.removeAll { $0 === closed }
        }
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

    private func performSearch(pattern: SearchPattern) {
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

    private func searchTermDescription(_ pattern: SearchPattern) -> String {
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
        if dividerIndex == 0 {
            return max(proposedMinimumPosition, 400)
        }
        // Divider 1: minimap has min width 80
        return max(proposedMinimumPosition, splitView.bounds.width - 220 - 100)
    }

    func splitView(
        _ splitView: NSSplitView,
        constrainMaxCoordinate proposedMaximumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        if dividerIndex == 0 {
            return splitView.bounds.width - 220 - 60
        }
        return splitView.bounds.width - 120
    }

    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        // Keep minimap and inspector fixed width when window resizes
        view !== dataInspector && view !== minimapView
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

extension AppDelegate: SelectBlockDelegate {
    func selectBlock(range: Range<Int>) {
        hexGrid.selectedRange = range
        hexGrid.cursorPosition = range.lowerBound
        hexGrid.scrollToOffset(range.lowerBound)
        hexGrid.needsDisplay = true
        updateStatusBar()
        updateDataInspector()
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
