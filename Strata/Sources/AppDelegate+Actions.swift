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

    @objc func toggleInsertModeAction() {
        hexGrid.isInsertMode.toggle(); updateStatusBar()
    }

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

    // MARK: - Update Check

    /// GitHub owner/repo for release checks.
    static let gitHubRepo = "ConnorHowell/strata"

    @objc func checkForUpdatesAction() {
        let urlString = "https://api.github.com/repos/"
            + "\(AppDelegate.gitHubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.handleUpdateResponse(data: data, error: error)
            }
        }.resume()
    }

    private func handleUpdateResponse(data: Data?, error: Error?) {
        guard let win = window else { return }

        if let error {
            let alert = NSAlert()
            alert.messageText = "Update Check Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.beginSheetModal(for: win)
            return
        }

        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            let alert = NSAlert()
            alert.messageText = "Update Check Failed"
            alert.informativeText = "Could not read release information from GitHub."
            alert.alertStyle = .warning
            alert.beginSheetModal(for: win)
            return
        }

        let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let current = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"

        let alert = NSAlert()
        if remote.compare(current, options: .numeric) == .orderedDescending {
            alert.messageText = "Update Available"
            alert.informativeText = "Version \(remote) is available "
                + "(you have \(current))."
            alert.addButton(withTitle: "Open Release Page")
            alert.addButton(withTitle: "Later")
            alert.beginSheetModal(for: win) { response in
                if response == .alertFirstButtonReturn,
                   let htmlURL = json["html_url"] as? String,
                   let url = URL(string: htmlURL) {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            alert.messageText = "You\u{2019}re Up to Date"
            alert.informativeText = "Strata \(current) is the latest version."
            alert.beginSheetModal(for: win)
        }
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

extension AppDelegate: NSSplitViewDelegate {
    func splitView(
        _ splitView: NSSplitView,
        constrainMinCoordinate proposedMinimumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        if dividerIndex == 0 {
            return max(proposedMinimumPosition, 400)
        }
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

    func splitView(
        _ splitView: NSSplitView,
        shouldAdjustSizeOfSubview view: NSView
    ) -> Bool {
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
