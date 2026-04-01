// FindCryptResultsPanel.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - FindCryptResultsPanel

/// Displays FindCrypt scan results in a table with click-to-navigate support.
public final class FindCryptResultsPanel: NSView {

    // MARK: - Public API

    /// Delegate for offset navigation.
    public weak var navigationDelegate: NavigableResultDelegate?

    /// Creates the panel with scan results.
    ///
    /// - Parameter matches: The FindCrypt matches to display.
    public init(matches: [FindCryptMatch]) {
        self.matches = matches
        super.init(frame: .zero)
        setupViews()
    }

    override public init(frame frameRect: NSRect) {
        self.matches = []
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Private

    private let matches: [FindCryptMatch]
    private let tableView = NSTableView()
    private var didConnect = false

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didConnect else { return }
        didConnect = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }

    private func setupViews() {
        let infoLabel = NSTextField(
            labelWithString: "\(matches.count) crypto signatures found"
        )
        infoLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoLabel)

        let columns = [
            ("Offset", 90.0),
            ("Algorithm", 200.0),
            ("Category", 120.0),
            ("Endianness", 80.0),
            ("Confidence", 80.0),
        ]
        for (title, width) in columns {
            let col = NSTableColumn(
                identifier: NSUserInterfaceItemIdentifier(title)
            )
            col.title = title
            col.width = CGFloat(width)
            col.minWidth = 40
            tableView.addTableColumn(col)
        }

        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = false
        tableView.target = self
        tableView.doubleAction = #selector(tableDoubleClicked)
        tableView.style = .plain
        tableView.rowHeight = 18

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(
                equalTo: topAnchor, constant: 8
            ),
            infoLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: 8
            ),
            scrollView.topAnchor.constraint(
                equalTo: infoLabel.bottomAnchor, constant: 6
            ),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < matches.count else { return }
        navigationDelegate?.navigateToOffset(matches[row].offset)
    }
}

// MARK: - NSTableViewDataSource

extension FindCryptResultsPanel: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        matches.count
    }
}

// MARK: - NSTableViewDelegate

extension FindCryptResultsPanel: NSTableViewDelegate {
    public func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard row < matches.count,
              let colID = tableColumn?.identifier else { return nil }
        let match = matches[row]

        let text: String
        let color: NSColor
        switch colID.rawValue {
        case "Offset":
            text = String(format: "0x%08X", match.offset)
            color = .labelColor
        case "Algorithm":
            text = match.signatureName
            color = .labelColor
        case "Category":
            text = match.category
            color = .secondaryLabelColor
        case "Endianness":
            text = match.endianness
            color = .labelColor
        case "Confidence":
            text = String(format: "%.0f%%", match.confidence * 100)
            color = match.confidence >= 1.0
                ? .systemGreen : .systemOrange
        default:
            text = ""
            color = .labelColor
        }

        if let existing = tableView.makeView(
            withIdentifier: colID, owner: self
        ) as? NSTableCellView {
            existing.textField?.stringValue = text
            existing.textField?.textColor = color
            return existing
        }

        let cellView = NSTableCellView()
        cellView.identifier = colID
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(label)
        cellView.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                equalTo: cellView.leadingAnchor, constant: 2
            ),
            label.trailingAnchor.constraint(
                equalTo: cellView.trailingAnchor, constant: -2
            ),
            label.centerYAnchor.constraint(
                equalTo: cellView.centerYAnchor
            ),
        ])
        return cellView
    }
}
