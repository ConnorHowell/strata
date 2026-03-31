// DiffView.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - DiffHighlightColor

/// Colors used for diff highlighting.
private enum DiffHighlightColor {
    static let deletion = NSColor.systemRed.withAlphaComponent(0.25)
    static let insertion = NSColor.systemGreen.withAlphaComponent(0.25)
    static let replacement = NSColor.systemYellow.withAlphaComponent(0.25)
}

// MARK: - DiffView

/// A side-by-side view comparing two byte sequences with diff highlighting.
public final class DiffView: NSView {

    // MARK: - Public API

    /// Initializes the diff view.
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Compares two data blocks and displays the diff.
    ///
    /// - Parameters:
    ///   - left: The original data.
    ///   - right: The modified data.
    public func compare(left: Data, right: Data) {
        leftData = left
        rightData = right

        leftTable = PieceTable(data: left)
        rightTable = PieceTable(data: right)
        leftGrid.dataSource = leftTable
        rightGrid.dataSource = rightTable

        diffResult = DiffEngine.diff(old: left, new: right)
        needsDisplay = true
        leftGrid.needsDisplay = true
        rightGrid.needsDisplay = true
    }

    /// Sets the file names displayed in the header.
    ///
    /// - Parameters:
    ///   - left: The left file name.
    ///   - right: The right file name.
    public func setFileNames(left: String, right: String) {
        leftNameLabel.stringValue = left
        rightNameLabel.stringValue = right
    }

    // MARK: - Private

    private let leftGrid = HexGridView()
    private let rightGrid = HexGridView()
    private let leftNameLabel = NSTextField(labelWithString: "Original")
    private let rightNameLabel = NSTextField(labelWithString: "Modified")
    private var leftData = Data()
    private var rightData = Data()
    private var leftTable: PieceTable?
    private var rightTable: PieceTable?
    private var diffResult: DiffResult?

    private func setupViews() {
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.distribution = .fillEqually
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        leftNameLabel.font = .boldSystemFont(ofSize: 12)
        rightNameLabel.font = .boldSystemFont(ofSize: 12)
        headerStack.addArrangedSubview(leftNameLabel)
        headerStack.addArrangedSubview(rightNameLabel)

        let gridStack = NSStackView()
        gridStack.orientation = .horizontal
        gridStack.distribution = .fillEqually
        gridStack.spacing = 2
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        leftGrid.translatesAutoresizingMaskIntoConstraints = false
        rightGrid.translatesAutoresizingMaskIntoConstraints = false
        gridStack.addArrangedSubview(leftGrid)
        gridStack.addArrangedSubview(rightGrid)

        addSubview(headerStack)
        addSubview(gridStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            gridStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 4),
            gridStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            gridStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
