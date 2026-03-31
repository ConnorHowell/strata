// DataInspector.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - DataInspector

/// A sidebar panel that displays the value at the current cursor position
/// in various formats using a table grid, matching HxD's Data Inspector.
public final class DataInspector: NSView {

    // MARK: - Public API

    /// Whether to use big-endian byte order.
    public var isBigEndian: Bool = false {
        didSet { reloadValues() }
    }

    /// Whether to display integer values in hexadecimal.
    public var showHex: Bool = false {
        didSet { reloadValues() }
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Updates the inspector with bytes starting at the given offset.
    ///
    /// - Parameters:
    ///   - dataSource: The piece table to read from.
    ///   - offset: The cursor position.
    public func update(dataSource: PieceTable?, offset: Int) {
        currentSource = dataSource
        currentOffset = offset
        reloadValues()
    }

    // MARK: - Private

    private var currentSource: PieceTable?
    private var currentOffset: Int = 0
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let endianToggle = NSSegmentedControl(
        labels: ["Little Endian", "Big Endian"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let hexToggle = NSSegmentedControl(
        labels: ["Decimal", "Hexadecimal"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private struct Row {
        let name: String
        var value: String
    }

    private static let typeNames = [
        "Binary", "Int8", "UInt8",
        "Int16", "UInt16", "Int32", "UInt32",
        "Int64", "UInt64", "Float", "Double",
    ]

    private var displayRows: [Row] = typeNames.map {
        Row(name: $0, value: "—")
    }

    private static let typeColumnID = NSUserInterfaceItemIdentifier("type")
    private static let valueColumnID = NSUserInterfaceItemIdentifier("value")

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        setAccessibilityIdentifier("dataInspector")

        // Type column
        let typeCol = NSTableColumn(identifier: Self.typeColumnID)
        typeCol.title = "Type"
        typeCol.width = 60
        typeCol.minWidth = 40
        typeCol.maxWidth = 100
        tableView.addTableColumn(typeCol)

        // Value column
        let valueCol = NSTableColumn(identifier: Self.valueColumnID)
        valueCol.title = "Value"
        valueCol.width = 140
        valueCol.minWidth = 60
        tableView.addTableColumn(valueCol)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 20
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.headerView = NSTableHeaderView()
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 6, height: 2)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        // Controls at bottom
        endianToggle.selectedSegment = 0
        endianToggle.target = self
        endianToggle.action = #selector(endianChanged)
        endianToggle.controlSize = .small
        endianToggle.translatesAutoresizingMaskIntoConstraints = false

        hexToggle.selectedSegment = 0
        hexToggle.target = self
        hexToggle.action = #selector(hexToggleChanged)
        hexToggle.controlSize = .small
        hexToggle.translatesAutoresizingMaskIntoConstraints = false

        let controlStack = NSStackView(views: [endianToggle, hexToggle])
        controlStack.orientation = .vertical
        controlStack.alignment = .leading
        controlStack.spacing = 4
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controlStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(
                equalTo: controlStack.topAnchor, constant: -6
            ),
            controlStack.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: 6
            ),
            controlStack.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -6
            ),
            controlStack.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -6
            ),
            endianToggle.widthAnchor.constraint(
                equalTo: controlStack.widthAnchor
            ),
            hexToggle.widthAnchor.constraint(
                equalTo: controlStack.widthAnchor
            ),
        ])
    }

    private func reloadValues() {
        computeValues()
        tableView.reloadData()
    }

    private func readBytes(_ count: Int) -> Data? {
        guard let ds = currentSource,
              currentOffset + count <= ds.totalLength else { return nil }
        return ds.bytes(in: currentOffset..<(currentOffset + count))
    }

    private func computeValues() {
        guard let ds = currentSource,
              currentOffset < ds.totalLength else {
            for i in displayRows.indices { displayRows[i].value = "—" }
            return
        }

        let b1 = readBytes(1)
        let b2 = readBytes(2)
        let b4 = readBytes(4)
        let b8 = readBytes(8)

        var idx = 0

        // Binary
        if let d = b1 {
            let bits = String(d[0], radix: 2)
            displayRows[idx].value = String(
                repeating: "0", count: 8 - bits.count
            ) + bits
        } else { displayRows[idx].value = "—" }
        idx += 1

        // Int8
        displayRows[idx].value = b1.map {
            fmtSigned(Int64(Int8(bitPattern: $0[0])), bits: 8)
        } ?? "—"
        idx += 1

        // UInt8
        displayRows[idx].value = b1.map {
            fmtUnsigned(UInt64($0[0]), bits: 8)
        } ?? "—"
        idx += 1

        // Int16
        displayRows[idx].value = b2.map {
            fmtSigned(Int64(toInt16($0)), bits: 16)
        } ?? "—"
        idx += 1

        // UInt16
        displayRows[idx].value = b2.map {
            fmtUnsigned(UInt64(toUInt16($0)), bits: 16)
        } ?? "—"
        idx += 1

        // Int32
        displayRows[idx].value = b4.map {
            fmtSigned(Int64(toInt32($0)), bits: 32)
        } ?? "—"
        idx += 1

        // UInt32
        displayRows[idx].value = b4.map {
            fmtUnsigned(UInt64(toUInt32($0)), bits: 32)
        } ?? "—"
        idx += 1

        // Int64
        displayRows[idx].value = b8.map {
            fmtSigned(toInt64($0), bits: 64)
        } ?? "—"
        idx += 1

        // UInt64
        displayRows[idx].value = b8.map {
            fmtUnsigned(toUInt64($0), bits: 64)
        } ?? "—"
        idx += 1

        // Float
        displayRows[idx].value = b4.map {
            "\(Float(bitPattern: toUInt32($0)))"
        } ?? "—"
        idx += 1

        // Double
        displayRows[idx].value = b8.map {
            "\(Double(bitPattern: toUInt64($0)))"
        } ?? "—"
    }

    private func fmtSigned(_ value: Int64, bits: Int) -> String {
        if showHex {
            let mask: UInt64 = bits == 64
                ? UInt64.max : (UInt64(1) << bits) - 1
            return String(
                format: "0x%0\(bits / 4)X",
                UInt64(bitPattern: value) & mask
            )
        }
        return "\(value)"
    }

    private func fmtUnsigned(_ value: UInt64, bits: Int) -> String {
        if showHex {
            return String(format: "0x%0\(bits / 4)X", value)
        }
        return "\(value)"
    }

    private func ordered(_ data: Data) -> Data {
        isBigEndian ? Data(data.reversed()) : data
    }

    private func toInt16(_ d: Data) -> Int16 {
        let o = ordered(d)
        return Int16(o[0]) | Int16(o[1]) << 8
    }

    private func toUInt16(_ d: Data) -> UInt16 {
        let o = ordered(d)
        return UInt16(o[0]) | UInt16(o[1]) << 8
    }

    private func toInt32(_ d: Data) -> Int32 {
        let o = ordered(d)
        return (0..<4).reduce(Int32(0)) { $0 | Int32(o[$1]) << ($1 * 8) }
    }

    private func toUInt32(_ d: Data) -> UInt32 {
        let o = ordered(d)
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(o[$1]) << ($1 * 8) }
    }

    private func toInt64(_ d: Data) -> Int64 {
        let o = ordered(d)
        return (0..<8).reduce(Int64(0)) { $0 | Int64(o[$1]) << ($1 * 8) }
    }

    private func toUInt64(_ d: Data) -> UInt64 {
        let o = ordered(d)
        return (0..<8).reduce(UInt64(0)) { $0 | UInt64(o[$1]) << ($1 * 8) }
    }

    @objc private func endianChanged() {
        isBigEndian = endianToggle.selectedSegment == 1
    }

    @objc private func hexToggleChanged() {
        showHex = hexToggle.selectedSegment == 1
    }
}

// MARK: - NSTableViewDataSource

extension DataInspector: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        displayRows.count
    }
}

// MARK: - NSTableViewDelegate

extension DataInspector: NSTableViewDelegate {
    public func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard let colID = tableColumn?.identifier else { return nil }
        let cellID = NSUserInterfaceItemIdentifier(
            "cell_\(colID.rawValue)"
        )
        let cell: NSTextField
        if let existing = tableView.makeView(
            withIdentifier: cellID, owner: nil
        ) as? NSTextField {
            cell = existing
        } else {
            cell = NSTextField(labelWithString: "")
            cell.identifier = cellID
            cell.isBordered = false
            cell.drawsBackground = false
            cell.lineBreakMode = .byTruncatingTail
        }

        let rowData = displayRows[row]
        if colID == Self.typeColumnID {
            cell.stringValue = rowData.name
            cell.font = .systemFont(ofSize: 11)
            cell.textColor = .secondaryLabelColor
        } else {
            cell.stringValue = rowData.value
            cell.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            cell.textColor = .labelColor
            cell.isSelectable = true
        }
        return cell
    }
}
