// StringsResultsPanel.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - NavigableResultDelegate

/// Delegate for navigating to a byte offset from a results panel.
public protocol NavigableResultDelegate: AnyObject {
    /// Navigate the hex view to the given byte offset.
    ///
    /// - Parameter offset: The byte offset to navigate to.
    func navigateToOffset(_ offset: Int)
}

// MARK: - StringsResultsPanel

/// Displays extracted strings in a table with column sorting and search.
public final class StringsResultsPanel: NSView {

    // MARK: - Public API

    /// Delegate for offset navigation.
    public weak var navigationDelegate: NavigableResultDelegate?

    /// Creates the panel with extracted string matches.
    ///
    /// - Parameter matches: The string matches to display.
    public init(matches: [StringMatch]) {
        self.allMatches = matches
        self.displayedMatches = matches
        super.init(frame: .zero)
        setupViews()
    }

    override public init(frame frameRect: NSRect) {
        self.allMatches = []
        self.displayedMatches = []
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Private

    private let allMatches: [StringMatch]
    private var displayedMatches: [StringMatch]
    private let tableView = NSTableView()
    private let searchField = NSSearchField()
    private let infoLabel = NSTextField(labelWithString: "")
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
        infoLabel.stringValue = "\(allMatches.count) strings found"
        infoLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoLabel)

        // Search field
        searchField.placeholderString = "Filter\u{2026}"
        searchField.font = .systemFont(ofSize: 11)
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        // Export button
        let exportBtn = NSButton(
            title: "Export\u{2026}",
            target: self, action: #selector(exportResults)
        )
        exportBtn.bezelStyle = .rounded
        exportBtn.controlSize = .small
        exportBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(exportBtn)

        // Table columns with sort descriptors
        let columns: [(String, Double, String)] = [
            ("Offset", 90.0, "offset"),
            ("String", 300.0, "value"),
            ("Encoding", 80.0, "encoding"),
            ("Length", 60.0, "length"),
        ]
        for (title, width, sortKey) in columns {
            let col = NSTableColumn(
                identifier: NSUserInterfaceItemIdentifier(title)
            )
            col.title = title
            col.width = CGFloat(width)
            col.minWidth = 40
            col.sortDescriptorPrototype = NSSortDescriptor(
                key: sortKey, ascending: true
            )
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
            searchField.centerYAnchor.constraint(
                equalTo: infoLabel.centerYAnchor
            ),
            searchField.leadingAnchor.constraint(
                equalTo: infoLabel.trailingAnchor, constant: 12
            ),
            searchField.widthAnchor.constraint(equalToConstant: 180),
            exportBtn.centerYAnchor.constraint(
                equalTo: infoLabel.centerYAnchor
            ),
            exportBtn.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -8
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

    // MARK: - Actions

    @objc private func searchChanged() {
        applyFilterAndSort()
    }

    @objc private func tableDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < displayedMatches.count else { return }
        navigationDelegate?.navigateToOffset(displayedMatches[row].offset)
    }

    @objc private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "strings.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var text = ""
        for match in displayedMatches {
            let hex = String(format: "0x%08X", match.offset)
            text += "\(hex)\t\(match.encoding.rawValue)\t\(match.value)\n"
        }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Filtering & Sorting

    private func applyFilterAndSort() {
        let query = searchField.stringValue
            .trimmingCharacters(in: .whitespaces).lowercased()

        if query.isEmpty {
            displayedMatches = allMatches
        } else {
            displayedMatches = allMatches.filter {
                $0.value.lowercased().contains(query)
            }
        }

        // Apply current sort descriptors
        for descriptor in tableView.sortDescriptors.reversed() {
            let asc = descriptor.ascending
            switch descriptor.key {
            case "offset":
                displayedMatches.sort {
                    asc ? $0.offset < $1.offset : $0.offset > $1.offset
                }
            case "value":
                displayedMatches.sort {
                    let cmp = $0.value.localizedCaseInsensitiveCompare(
                        $1.value
                    )
                    return asc
                        ? cmp == .orderedAscending
                        : cmp == .orderedDescending
                }
            case "encoding":
                displayedMatches.sort {
                    asc
                        ? $0.encoding.rawValue < $1.encoding.rawValue
                        : $0.encoding.rawValue > $1.encoding.rawValue
                }
            case "length":
                displayedMatches.sort {
                    asc
                        ? $0.byteLength < $1.byteLength
                        : $0.byteLength > $1.byteLength
                }
            default:
                break
            }
        }

        tableView.reloadData()
        updateInfoLabel()
    }

    private func updateInfoLabel() {
        if displayedMatches.count == allMatches.count {
            infoLabel.stringValue = "\(allMatches.count) strings found"
        } else {
            infoLabel.stringValue =
                "\(displayedMatches.count) of \(allMatches.count) strings"
        }
    }
}

// MARK: - NSTableViewDataSource

extension StringsResultsPanel: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        displayedMatches.count
    }

    public func tableView(
        _ tableView: NSTableView,
        sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]
    ) {
        applyFilterAndSort()
    }
}

// MARK: - NSTableViewDelegate

extension StringsResultsPanel: NSTableViewDelegate {
    public func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard row < displayedMatches.count,
              let colID = tableColumn?.identifier else { return nil }
        let match = displayedMatches[row]

        let text: String
        switch colID.rawValue {
        case "Offset":
            text = String(format: "0x%08X", match.offset)
        case "String":
            text = match.value
        case "Encoding":
            text = match.encoding.rawValue
        case "Length":
            text = "\(match.byteLength)"
        default:
            text = ""
        }

        if let existing = tableView.makeView(
            withIdentifier: colID, owner: self
        ) as? NSTableCellView {
            existing.textField?.stringValue = text
            return existing
        }

        let cellView = NSTableCellView()
        cellView.identifier = colID
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
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
