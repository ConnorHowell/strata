// ChecksumPanel.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - ChecksumPanel

/// A panel that displays computed checksums and hashes for the current data.
public final class ChecksumPanel: NSView {

    // MARK: - Public API

    /// Initializes the checksum panel.
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Updates the displayed checksums for the given data.
    ///
    /// - Parameter data: The data to compute checksums for.
    public func update(with data: Data) {
        Task { @MainActor in
            let results = await computeChecksums(for: data)
            for type in ChecksumType.allCases {
                guard let label = valueLabels[type] else { continue }
                label.stringValue = results[type] ?? "—"
            }
        }
    }

    /// Clears all displayed values.
    public func clear() {
        for label in valueLabels.values {
            label.stringValue = "—"
        }
    }

    // MARK: - Private

    private var valueLabels: [ChecksumType: NSTextField] = [:]

    private func setupViews() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])

        let title = NSTextField(labelWithString: "Checksums")
        title.font = .boldSystemFont(ofSize: 13)
        stack.addArrangedSubview(title)

        for type in ChecksumType.allCases {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 4

            let nameLabel = NSTextField(labelWithString: "\(type.rawValue):")
            nameLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
            nameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            let valueLabel = NSTextField(labelWithString: "—")
            valueLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            valueLabel.isSelectable = true
            valueLabel.lineBreakMode = .byTruncatingTail

            let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyValue(_:)))
            copyButton.bezelStyle = .inline
            copyButton.controlSize = .small
            copyButton.tag = type.hashValue

            row.addArrangedSubview(nameLabel)
            row.addArrangedSubview(valueLabel)
            row.addArrangedSubview(copyButton)
            stack.addArrangedSubview(row)

            valueLabels[type] = valueLabel
        }
    }

    private func computeChecksums(for data: Data) async -> [ChecksumType: String] {
        await withCheckedContinuation { continuation in
            let results = ChecksumEngine.computeAll(data: data)
            continuation.resume(returning: results)
        }
    }

    @objc private func copyValue(_ sender: NSButton) {
        for (type, label) in valueLabels where type.hashValue == sender.tag {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(label.stringValue, forType: .string)
            break
        }
    }
}
