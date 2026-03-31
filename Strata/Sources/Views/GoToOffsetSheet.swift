// GoToOffsetSheet.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - GoToOffsetDelegate

/// Delegate for handling offset navigation requests.
public protocol GoToOffsetDelegate: AnyObject {
    /// Called when the user confirms an offset to navigate to.
    func goToOffset(_ offset: Int)
}

// MARK: - GoToOffsetSheet

/// A sheet view controller for navigating to a specific byte offset.
///
/// Accepts hex input with `0x` prefix or plain decimal numbers.
public final class GoToOffsetSheet: NSViewController {

    // MARK: - Public API

    /// The delegate to receive navigation requests.
    public weak var offsetDelegate: GoToOffsetDelegate?

    /// The maximum valid offset for validation.
    public var maxOffset: Int = 0

    override public func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        setupViews()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        offsetField.setAccessibilityIdentifier("goToOffsetField")
    }

    // MARK: - Private

    private let offsetField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")

    private func setupViews() {
        let label = NSTextField(labelWithString: "Enter offset (hex 0x... or decimal):")
        label.translatesAutoresizingMaskIntoConstraints = false

        offsetField.placeholderString = "0x0000 or 0"
        offsetField.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        let okButton = NSButton(title: "OK", target: self, action: #selector(okTapped))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.setAccessibilityIdentifier("goToOK")

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        for subview in [label, offsetField, errorLabel, okButton, cancelButton] as [NSView] {
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            offsetField.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            offsetField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            offsetField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            errorLabel.topAnchor.constraint(equalTo: offsetField.bottomAnchor, constant: 4),
            errorLabel.leadingAnchor.constraint(equalTo: offsetField.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            okButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            okButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    /// Parses the offset string, supporting 0x hex prefix and decimal.
    ///
    /// - Parameter text: The input text.
    /// - Returns: The parsed offset, or `nil` if invalid.
    private func parseOffset(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("0x") {
            let hexStr = String(trimmed.dropFirst(2))
            return Int(hexStr, radix: 16)
        }
        return Int(trimmed)
    }

    @objc private func okTapped() {
        let text = offsetField.stringValue
        guard let offset = parseOffset(text) else {
            errorLabel.stringValue = "Invalid offset format."
            return
        }
        guard offset >= 0, offset <= maxOffset else {
            errorLabel.stringValue = "Offset out of range (0–\(String(format: "0x%X", maxOffset)))."
            return
        }
        dismiss(nil)
        offsetDelegate?.goToOffset(offset)
    }

    @objc private func cancelTapped() {
        dismiss(nil)
    }
}
