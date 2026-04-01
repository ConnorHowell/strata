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
        setAccessibilityElement(true)
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

// MARK: - EmptyStateView

/// A centered empty state shown when no files are open.
final class EmptyStateView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupViews() {
        let logoView = StrataLogoMark(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        logoView.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Strata")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: "Drop a file here to open it")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .tertiaryLabelColor
        subtitle.alignment = .center

        let hint = NSTextField(
            labelWithString: "or use File \u{2192} Open (\u{2318}O)"
                + " \u{00B7} File \u{2192} New (\u{2318}N)"
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .quaternaryLabelColor
        hint.alignment = .center

        let textStack = NSStackView(views: [logoView, title, subtitle, hint])
        textStack.orientation = .vertical
        textStack.alignment = .centerX
        textStack.spacing = 8
        textStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textStack)

        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 80),
            logoView.heightAnchor.constraint(equalToConstant: 80),
            textStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

/// Draws the Strata "S" logo mark — five staggered rounded bars in monochrome.
final class StrataLogoMark: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let barH = h * 0.1
        let gap = (h - barH * 5) / 6
        let barW = w * 0.55

        // x-offsets matching the SVG's S-curve shape (normalized)
        let offsets: [CGFloat] = [0.35, -0.10, 0.13, 0.35, -0.10]

        let color = NSColor.tertiaryLabelColor
        ctx.setFillColor(color.cgColor)

        for i in 0..<5 {
            let x = (w - barW) / 2 + offsets[i] * barW * 0.4
            let y = gap + CGFloat(i) * (barH + gap)
            let rect = CGRect(x: x, y: y, width: barW, height: barH)
            let path = CGPath(
                roundedRect: rect,
                cornerWidth: barH / 2,
                cornerHeight: barH / 2,
                transform: nil
            )
            ctx.addPath(path)
            ctx.fillPath()
        }
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
    let hexScrollBar = HexScrollBar(frame: .zero)
    let minimapView = MinimapView(frame: .zero)
    let hexEditorContainer = NSView(frame: .zero)
    let splitView = NSSplitView()
    let emptyStateView = EmptyStateView(frame: .zero)
    let findBar = FindBar(frame: .zero)
    var isMinimapVisible = true
    /// The last search pattern, used for Find Next / Find Previous.
    var lastSearchPattern: SearchPattern?
    /// Constraint pinning splitView top to findBar or tabBar.
    var splitViewTopConstraint: NSLayoutConstraint?
    /// Current match index (1-based).
    var searchMatchIndex: Int = 0
    /// Total matches for current search pattern.
    var searchMatchTotal: Int = 0
    var isChecksumPanelVisible = false
    var recentFileURLs: [URL] = []
    static let maxRecentFiles = 10
    /// Retains auxiliary windows (stats, diff) so ARC doesn't deallocate them.
    var auxiliaryWindows: [NSWindow] = []

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadRecentFiles()
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
        let hasSessions = !sessionManager.sessions.isEmpty
        emptyStateView.isHidden = hasSessions
        splitView.isHidden = !hasSessions
        tabBar.isHidden = !hasSessions

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
        updateScrollComponents()
        updateStatusBar()
        updateDataInspector()
        window?.title = sessionManager.activeSession?.fileName ?? "Strata"
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

    func updateScrollComponents() {
        let rows = hexGrid.totalRows
        let visible = hexGrid.visibleRowRange.count
        hexScrollBar.totalRows = rows
        hexScrollBar.visibleRows = visible
        hexScrollBar.updateFromScrollOffset(hexGrid.scrollOffset)
        minimapView.dataSource = hexGrid.dataSource
        minimapView.bytesPerRow = hexGrid.bytesPerRow
        minimapView.totalRows = rows
        minimapView.visibleRows = visible
        minimapView.scrollOffset = hexGrid.scrollOffset
        minimapView.invalidateCache()
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
        win.tabbingMode = .disallowed
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

        // Hex editor container: hex grid + scrollbar
        hexEditorContainer.translatesAutoresizingMaskIntoConstraints = false
        hexGrid.translatesAutoresizingMaskIntoConstraints = false
        hexScrollBar.translatesAutoresizingMaskIntoConstraints = false
        hexEditorContainer.addSubview(hexGrid)
        hexEditorContainer.addSubview(hexScrollBar)
        let scrollerW = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        NSLayoutConstraint.activate([
            hexGrid.topAnchor.constraint(equalTo: hexEditorContainer.topAnchor),
            hexGrid.leadingAnchor.constraint(equalTo: hexEditorContainer.leadingAnchor),
            hexGrid.bottomAnchor.constraint(equalTo: hexEditorContainer.bottomAnchor),
            hexGrid.trailingAnchor.constraint(equalTo: hexScrollBar.leadingAnchor),
            hexScrollBar.topAnchor.constraint(equalTo: hexEditorContainer.topAnchor),
            hexScrollBar.trailingAnchor.constraint(equalTo: hexEditorContainer.trailingAnchor),
            hexScrollBar.bottomAnchor.constraint(equalTo: hexEditorContainer.bottomAnchor),
            hexScrollBar.widthAnchor.constraint(equalToConstant: scrollerW),
        ])

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.addSubview(hexEditorContainer)
        splitView.addSubview(minimapView)
        splitView.addSubview(dataInspector)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 1)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 2)

        // Wire scroll synchronization
        hexGrid.onScrollOffsetChanged = { [weak self] offset in
            guard let self else { return }
            self.hexScrollBar.updateFromScrollOffset(offset)
            self.minimapView.scrollOffset = offset
            self.minimapView.totalRows = self.hexGrid.totalRows
            self.minimapView.visibleRows = self.hexGrid.visibleRowRange.count
            self.hexScrollBar.totalRows = self.hexGrid.totalRows
            self.hexScrollBar.visibleRows = self.hexGrid.visibleRowRange.count
        }
        hexScrollBar.onScrollOffsetChanged = { [weak self] offset in
            self?.hexGrid.scrollOffset = offset
        }
        minimapView.onScrollOffsetChanged = { [weak self] offset in
            self?.hexGrid.scrollOffset = offset
        }
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        findBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.isHidden = true
        findBar.delegate = self
        contentView.addSubview(tabBar)
        contentView.addSubview(findBar)
        contentView.addSubview(splitView)
        contentView.addSubview(statusBar)
        contentView.addSubview(emptyStateView)

        let svTop = splitView.topAnchor.constraint(equalTo: tabBar.bottomAnchor)
        splitViewTopConstraint = svTop

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 30),
            findBar.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            findBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            findBar.heightAnchor.constraint(equalToConstant: 32),
            svTop,
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            emptyStateView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),
        ])

        win.makeKeyAndOrderFront(nil)
        window = win
        splitView.layoutSubtreeIfNeeded()
        let w = splitView.bounds.width
        // Set dividers left-to-right: hex container | minimap | inspector
        splitView.setPosition(w - 220 - 80, ofDividerAt: 0)
        splitView.setPosition(w - 220, ofDividerAt: 1)
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
}
