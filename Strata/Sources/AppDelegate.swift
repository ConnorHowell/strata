// AppDelegate.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - StatusBarView

/// A status bar at the bottom of the window showing cursor offset, selection, and mode.
public final class StatusBarView: NSView {

    // MARK: - Public API

    /// Updates the status bar display.
    ///
    /// - Parameters:
    ///   - offset: The current cursor offset.
    ///   - selection: The selection size in bytes.
    ///   - insertMode: Whether insert mode is active.
    ///   - fileSize: The total file size.
    public func update(offset: Int, selection: Int, insertMode: Bool, fileSize: Int) {
        offsetLabel.stringValue = String(format: "Offset: 0x%08X", offset)
        selectionLabel.stringValue = selection > 0 ? "Sel: \(selection) bytes" : "Sel: —"
        modeLabel.stringValue = insertMode ? "INS" : "OVR"
        sizeLabel.stringValue = "Size: \(fileSize) bytes"
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Private

    private let offsetLabel = NSTextField(labelWithString: "Offset: 0x00000000")
    private let selectionLabel = NSTextField(labelWithString: "Sel: —")
    private let modeLabel = NSTextField(labelWithString: "OVR")
    private let sizeLabel = NSTextField(labelWithString: "Size: 0 bytes")

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        setAccessibilityIdentifier("statusBar")
        modeLabel.setAccessibilityIdentifier("modeIndicator")

        let stack = NSStackView(views: [offsetLabel, selectionLabel, modeLabel, sizeLabel])
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        for label in [offsetLabel, selectionLabel, modeLabel, sizeLabel] {
            label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

// MARK: - DropTargetView

/// A content view that accepts file drags and forwards them to a handler.
final class DropTargetView: NSView {

    // MARK: - Public API

    /// Called when files are dropped onto the view.
    var onFilesDropped: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }
}

// MARK: - AppDelegate

/// The main application delegate. Creates the window and wires all UI programmatically.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    var window: NSWindow?
    let sessionManager = SessionManager()
    let tabBar = TabBar(frame: .zero)
    let hexGrid = HexGridView()
    let statusBar = StatusBarView(frame: .zero)
    let findPanel = FindReplacePanel(frame: .zero)
    let checksumPanel = ChecksumPanel(frame: .zero)
    let dataInspector = DataInspector(frame: .zero)
    let splitView = NSSplitView()
    var isChecksumPanelVisible = false

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupWindow()
        sessionManager.delegate = self
        hexGrid.delegate = self
        tabBar.delegate = self
        findPanel.delegate = self
        hexGrid.configureAccessibility(identifier: "hexGridView")
        refreshUI()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Handles files dropped onto the dock icon or opened via Finder.
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            do {
                try sessionManager.openFile(at: url)
            } catch {
                showError(error)
            }
        }
        refreshUI()
        sender.reply(toOpenOrPrint: .success)
    }

    // MARK: - Internal

    func refreshUI() {
        let titles = sessionManager.sessions.map(\.fileName)
        tabBar.update(titles: titles, activeIndex: sessionManager.activeSessionIndex)
        let pt = sessionManager.activeSession?.pieceTable
        hexGrid.dataSource = pt
        // Clamp cursor and selection to valid range for the new data source
        let len = pt?.totalLength ?? 0
        if hexGrid.cursorPosition >= len {
            hexGrid.cursorPosition = max(0, len - 1)
        }
        if let sel = hexGrid.selectedRange, sel.upperBound > len {
            hexGrid.selectedRange = nil
        }
        hexGrid.scrollOffset = 0
        hexGrid.pendingNibble = nil
        hexGrid.needsDisplay = true
        updateStatusBar()
        updateDataInspector()
    }

    func updateStatusBar() {
        let offset = hexGrid.cursorPosition
        let sel = hexGrid.selectedRange?.count ?? 0
        let size = sessionManager.activeSession?.pieceTable.totalLength ?? 0
        statusBar.update(
            offset: offset,
            selection: sel,
            insertMode: hexGrid.isInsertMode,
            fileSize: size
        )
    }

    func updateDataInspector() {
        dataInspector.update(
            dataSource: sessionManager.activeSession?.pieceTable,
            offset: hexGrid.cursorPosition
        )
    }

    func openDroppedFiles(_ urls: [URL]) {
        for url in urls {
            do {
                try sessionManager.openFile(at: url)
            } catch {
                showError(error)
            }
        }
        refreshUI()
    }

    // MARK: - Private

    private func setupWindow() {
        let rect = NSRect(x: 0, y: 0, width: 1200, height: 800)
        let mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let win = NSWindow(contentRect: rect, styleMask: mask, backing: .buffered, defer: false)
        win.title = "Strata"
        win.minSize = NSSize(width: 800, height: 600)
        win.center()
        win.setAccessibilityIdentifier("mainWindow")

        let contentView = DropTargetView(frame: rect)
        contentView.onFilesDropped = { [weak self] urls in
            self?.openDroppedFiles(urls)
        }
        win.contentView = contentView

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        splitView.translatesAutoresizingMaskIntoConstraints = false

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.addSubview(hexGrid)
        splitView.addSubview(dataInspector)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 1)
        contentView.addSubview(tabBar)
        contentView.addSubview(splitView)
        contentView.addSubview(statusBar)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 30),
            splitView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),
        ])

        win.makeKeyAndOrderFront(nil)
        window = win
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.splitView.setPosition(
                self.splitView.bounds.width - 220, ofDividerAt: 0
            )
        }
    }

    func setupMainMenu() {
        let mainMenu = NSMenu()
        mainMenu.addItem(buildAppMenu())
        mainMenu.addItem(buildFileMenu())
        mainMenu.addItem(buildEditMenu())
        mainMenu.addItem(buildViewMenu())
        mainMenu.addItem(buildToolsMenu())
        NSApplication.shared.mainMenu = mainMenu
    }

    private func buildAppMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Strata")
        menu.addItem(
            withTitle: "About Strata",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Strata", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu
        return item
    }

    private func buildFileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "New", action: #selector(newFileAction), keyEquivalent: "n")
        menu.addItem(withTitle: "Open…", action: #selector(openFileAction), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Save", action: #selector(saveFileAction), keyEquivalent: "s")
        let saveAs = menu.addItem(withTitle: "Save As…", action: #selector(saveFileAsAction), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close Tab", action: #selector(closeTabAction), keyEquivalent: "w")
        item.submenu = menu
        return item
    }

    private func buildEditMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: #selector(undoAction), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: #selector(redoAction), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(cutAction), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(copyAction), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(pasteAction), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(selectAllAction), keyEquivalent: "a")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Find…", action: #selector(showFindAction), keyEquivalent: "f")
        menu.addItem(withTitle: "Replace…", action: #selector(showReplaceAction), keyEquivalent: "h")
        menu.addItem(withTitle: "Go To Offset…", action: #selector(showGoToAction), keyEquivalent: "g")
        item.submenu = menu
        return item
    }

    private func buildViewMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")
        menu.addItem(
            withTitle: "Toggle Checksum Panel",
            action: #selector(toggleChecksumPanelAction),
            keyEquivalent: ""
        )
        menu.addItem(withTitle: "Toggle Insert Mode", action: #selector(toggleInsertModeAction), keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func buildToolsMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Tools")
        menu.addItem(withTitle: "Compare Files…", action: #selector(compareToolAction), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Import Intel HEX…", action: #selector(importIntelHexAction), keyEquivalent: "")
        menu.addItem(withTitle: "Import S-Record…", action: #selector(importSRecordAction), keyEquivalent: "")
        menu.addItem(withTitle: "Export Intel HEX…", action: #selector(exportIntelHexAction), keyEquivalent: "")
        menu.addItem(withTitle: "Export S-Record…", action: #selector(exportSRecordAction), keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
