// ChecksumResultsPanel.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - ChecksumResult

/// A single checksum computation result with optional comparison.
public struct ChecksumResult {
    /// The algorithm used.
    public let type: ChecksumType
    /// The computed hex value.
    public let value: String
    /// Whether the value matches the expected comparison hex (nil if no comparison).
    public let matches: Bool?
}

// MARK: - ChecksumResultsPanel

/// Displays computed checksum results with optional comparison indicators.
public final class ChecksumResultsPanel: NSView {

    // MARK: - Public API

    /// Creates the results panel with the given results.
    ///
    /// - Parameter results: The checksum results to display.
    public init(results: [ChecksumResult]) {
        self.results = results
        super.init(frame: .zero)
        setupViews()
    }

    override public init(frame frameRect: NSRect) {
        self.results = []
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Private

    private let results: [ChecksumResult]

    private func setupViews() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])

        for result in results {
            let row = buildRow(for: result)
            stack.addArrangedSubview(row)
        }
    }

    private func buildRow(for result: ChecksumResult) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY

        // Match indicator (if comparing)
        if let matches = result.matches {
            let indicator = NSTextField(labelWithString: matches ? "\u{2713}" : "\u{2717}")
            indicator.font = .systemFont(ofSize: 14, weight: .bold)
            indicator.textColor = matches ? .systemGreen : .systemRed
            indicator.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(indicator)
        }

        // Algorithm name
        let nameLabel = NSTextField(labelWithString: "\(result.type.rawValue):")
        nameLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        nameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true

        // Value (selectable)
        let valueLabel = NSTextField(labelWithString: result.value)
        valueLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        valueLabel.isSelectable = true
        valueLabel.lineBreakMode = .byTruncatingTail

        // Copy button
        let copyButton = NSButton(title: "Copy", target: self,
                                   action: #selector(copyValue(_:)))
        copyButton.bezelStyle = .inline
        copyButton.controlSize = .small
        copyButton.identifier = NSUserInterfaceItemIdentifier(result.value)

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(valueLabel)
        row.addArrangedSubview(copyButton)

        return row
    }

    @objc private func copyValue(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
