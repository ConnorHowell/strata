// AppDelegate+Tools.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - Tool Action Handlers

extension AppDelegate {

    @objc func generateChecksumsAction() {
        guard sessionManager.activeSession != nil else { return }
        let sheet = ChecksumSheet()
        sheet.sheetDelegate = self
        sheet.hasSelection = hexGrid.selectedRange != nil
        guard let win = window else { return }
        let hostVC = NSViewController()
        hostVC.view = win.contentView ?? NSView()
        hostVC.presentAsSheet(sheet)
    }

    @objc func stringsAction() {
        guard sessionManager.activeSession != nil else { return }
        let sheet = StringsSheet()
        sheet.sheetDelegate = self
        sheet.hasSelection = hexGrid.selectedRange != nil
        guard let win = window else { return }
        let hostVC = NSViewController()
        hostVC.view = win.contentView ?? NSView()
        hostVC.presentAsSheet(sheet)
    }

    @objc func findCryptAction() {
        guard let session = sessionManager.activeSession else { return }
        let len = session.pieceTable.totalLength
        guard len > 0 else { return }
        let data = session.pieceTable.bytes(in: 0..<len)

        guard let sigURL = Bundle.main.url(
            forResource: "FindCryptSignatures", withExtension: "json"
        ) else {
            showError(NSError(
                domain: "Strata", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Signatures database not found."]
            ))
            return
        }

        let fileName = session.fileName
        let progress = showProgressPanel(title: "Scanning for crypto constants\u{2026}")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let signatures = FindCryptEngine.loadSignatures(from: sigURL)
            let matches = FindCryptEngine.scan(data: data, signatures: signatures)
            DispatchQueue.main.async {
                progress.close()
                guard let self else { return }
                let panel = FindCryptResultsPanel(matches: matches)
                panel.navigationDelegate = self
                let fcWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 700, height: 400),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                fcWindow.isReleasedWhenClosed = false
                fcWindow.title = "FindCrypt \u{2014} \(fileName)"
                fcWindow.contentView = panel
                fcWindow.center()
                fcWindow.makeKeyAndOrderFront(nil)
                self.retainAuxiliaryWindow(fcWindow)
            }
        }
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
            diffWindow.title = "Compare: \(session.fileName) \u{2194} \(url.lastPathComponent)"
            diffWindow.contentView = diffView
            diffWindow.center()
            diffWindow.makeKeyAndOrderFront(nil)
            retainAuxiliaryWindow(diffWindow)
        } catch {
            showError(error)
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
        statsWindow.title = "Byte Statistics \u{2014} \(session.fileName)"
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
            self.performSplit(session: session, len: len, chunkSize: chunkSize, win: win)
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
        do {
            try hex.write(to: url, atomically: true, encoding: .utf8)
        } catch { showError(error) }
    }

    @objc func exportSRecordAction() {
        guard let session = sessionManager.activeSession else { return }
        let panel = NSSavePanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = session.pieceTable.bytes(in: 0..<session.pieceTable.totalLength)
        let srec = SRecord.fromData(data)
        do {
            try srec.write(to: url, atomically: true, encoding: .utf8)
        } catch { showError(error) }
    }

    // MARK: - Private Helpers

    private func performSplit(
        session: FileSession, len: Int, chunkSize: Int, win: NSWindow
    ) {
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
            let name = String(format: "%@.%03d", session.fileName, partNum)
            let fileURL = dir.appendingPathComponent(name)
            do {
                try Data(chunk).write(to: fileURL, options: .atomic)
            } catch {
                showError(error)
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

    /// Shows a floating progress panel with a spinner and message.
    ///
    /// - Parameter title: The message to display.
    /// - Returns: The progress window (caller should call `.close()` when done).
    func showProgressPanel(title: String) -> NSWindow {
        let progressWin = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        progressWin.isReleasedWhenClosed = false
        progressWin.title = ""

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [spinner, label])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = progressWin.contentView ?? NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])

        progressWin.center()
        progressWin.makeKeyAndOrderFront(nil)
        return progressWin
    }

    /// Returns the data for the specified region.
    func dataForRegion(_ region: ChecksumRegion) -> Data? {
        guard let session = sessionManager.activeSession else { return nil }
        switch region {
        case .selection:
            guard let range = hexGrid.selectedRange else { return nil }
            return session.pieceTable.bytes(in: range)
        case .entireFile:
            let len = session.pieceTable.totalLength
            guard len > 0 else { return nil }
            return session.pieceTable.bytes(in: 0..<len)
        }
    }
}

// MARK: - ChecksumSheetDelegate

extension AppDelegate: ChecksumSheetDelegate {
    func checksumSheet(
        _ sheet: ChecksumSheet,
        didSelectTypes types: [ChecksumType],
        region: ChecksumRegion,
        compareHex: String?
    ) {
        guard let data = dataForRegion(region) else { return }
        let normalizedCompare = compareHex?.lowercased()
            .trimmingCharacters(in: .whitespaces)

        var results: [ChecksumResult] = []
        for type in types {
            let value = ChecksumEngine.compute(type, data: data)
            let matches: Bool?
            if let comp = normalizedCompare, !comp.isEmpty {
                matches = value == comp
            } else {
                matches = nil
            }
            results.append(ChecksumResult(type: type, value: value, matches: matches))
        }

        guard let session = sessionManager.activeSession else { return }
        let panel = ChecksumResultsPanel(results: results)
        let csWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        csWindow.isReleasedWhenClosed = false
        csWindow.title = "Checksums \u{2014} \(session.fileName)"
        csWindow.contentView = panel
        csWindow.center()
        csWindow.makeKeyAndOrderFront(nil)
        retainAuxiliaryWindow(csWindow)
    }
}

// MARK: - StringsSheetDelegate

extension AppDelegate: StringsSheetDelegate {
    func stringsSheet(
        _ sheet: StringsSheet,
        didConfigure minLength: Int,
        encodings: Set<StringMatchEncoding>,
        region: ChecksumRegion
    ) {
        guard let session = sessionManager.activeSession else { return }
        let fileName = session.fileName

        // Always use piece table data — reading from the file URL
        // directly fails in sandboxed builds where security-scoped
        // access has expired.
        guard let regionData = dataForRegion(region) else { return }

        let progress = showProgressPanel(title: "Extracting strings\u{2026}")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let matches = StringsEngine.scan(
                data: regionData,
                minLength: minLength,
                encodings: encodings
            )
            DispatchQueue.main.async {
                progress.close()
                guard let self else { return }
                let panel = StringsResultsPanel(matches: matches)
                panel.navigationDelegate = self
                let strWindow = NSWindow(
                    contentRect: NSRect(
                        x: 0, y: 0, width: 600, height: 400
                    ),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                strWindow.isReleasedWhenClosed = false
                strWindow.title = "Strings \u{2014} \(fileName)"
                strWindow.contentView = panel
                strWindow.center()
                strWindow.makeKeyAndOrderFront(nil)
                self.retainAuxiliaryWindow(strWindow)
            }
        }
    }
}

// MARK: - NavigableResultDelegate

extension AppDelegate: NavigableResultDelegate {
    func navigateToOffset(_ offset: Int) {
        hexGrid.scrollToOffset(offset)
        hexGrid.cursorPosition = offset
        updateStatusBar()
        updateDataInspector()
    }
}
