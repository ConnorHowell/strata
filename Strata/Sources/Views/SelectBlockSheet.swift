// SelectBlockSheet.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - SelectBlockDelegate

/// Delegate for handling block selection requests.
public protocol SelectBlockDelegate: AnyObject {
    /// Called when the user confirms a block selection.
    func selectBlock(range: Range<Int>)
}

// MARK: - SelectBlockSheet

/// A sheet view controller for selecting a byte range,
/// matching HxD's Select Block dialog with start/end/length and hex/dec/oct.
public final class SelectBlockSheet: NSViewController {

    // MARK: - Public API

    /// The delegate to receive selection requests.
    public weak var blockDelegate: SelectBlockDelegate?

    /// The maximum valid offset for validation.
    public var maxOffset: Int = 0

    /// Pre-populated start offset (current cursor).
    public var initialStart: Int = 0

    override public func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 230))
        setupViews()
    }

    override public func viewDidAppear() {
        super.viewDidAppear()
        startField.stringValue = formatValue(initialStart)
    }

    // MARK: - Private

    private let startField = NSTextField()
    private let endField = NSTextField()
    private let lengthField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")
    private var baseRadios: [NSButton] = []
    private var endRadio = NSButton()
    private var lengthRadio = NSButton()

    private func setupViews() {
        // Start offset
        let startLabel = NSTextField(labelWithString: "Start-offset:")
        startLabel.font = .systemFont(ofSize: 12)
        startLabel.translatesAutoresizingMaskIntoConstraints = false

        startField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        startField.translatesAutoresizingMaskIntoConstraints = false

        // End offset (radio + field)
        endRadio = NSButton(
            radioButtonWithTitle: "End-offset:",
            target: self,
            action: #selector(modeChanged)
        )
        endRadio.state = .on
        endRadio.tag = 0
        endRadio.translatesAutoresizingMaskIntoConstraints = false

        endField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        endField.translatesAutoresizingMaskIntoConstraints = false

        // Length (radio + field)
        lengthRadio = NSButton(
            radioButtonWithTitle: "Length:",
            target: self,
            action: #selector(modeChanged)
        )
        lengthRadio.state = .off
        lengthRadio.tag = 1
        lengthRadio.translatesAutoresizingMaskIntoConstraints = false

        lengthField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        lengthField.isEnabled = false
        lengthField.translatesAutoresizingMaskIntoConstraints = false

        // Base radios
        let hexRadio = NSButton(
            radioButtonWithTitle: "hex", target: self, action: #selector(baseChanged)
        )
        let decRadio = NSButton(
            radioButtonWithTitle: "dec", target: self, action: #selector(baseChanged)
        )
        let octRadio = NSButton(
            radioButtonWithTitle: "oct", target: self, action: #selector(baseChanged)
        )
        hexRadio.state = .on
        hexRadio.tag = 16
        decRadio.tag = 10
        octRadio.tag = 8
        baseRadios = [hexRadio, decRadio, octRadio]

        let baseStack = NSStackView(views: [hexRadio, decRadio, octRadio])
        baseStack.orientation = .horizontal
        baseStack.spacing = 12
        baseStack.translatesAutoresizingMaskIntoConstraints = false

        // Error label
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        let okButton = NSButton(title: "OK", target: self, action: #selector(okTapped))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let buttonStack = NSStackView(views: [cancelButton, okButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let allViews: [NSView] = [
            startLabel, startField,
            endRadio, endField,
            lengthRadio, lengthField,
            baseStack, errorLabel, buttonStack,
        ]
        for sub in allViews { view.addSubview(sub) }

        let margin: CGFloat = 16
        NSLayoutConstraint.activate([
            startLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            startLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            startField.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 4),
            startField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            startField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            endRadio.topAnchor.constraint(equalTo: startField.bottomAnchor, constant: 10),
            endRadio.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            endField.topAnchor.constraint(equalTo: endRadio.bottomAnchor, constant: 4),
            endField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            endField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            lengthRadio.topAnchor.constraint(equalTo: endField.bottomAnchor, constant: 8),
            lengthRadio.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            lengthField.topAnchor.constraint(equalTo: lengthRadio.bottomAnchor, constant: 4),
            lengthField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            lengthField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            baseStack.topAnchor.constraint(equalTo: lengthField.bottomAnchor, constant: 10),
            baseStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            errorLabel.topAnchor.constraint(equalTo: baseStack.bottomAnchor, constant: 4),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private var selectedBase: Int {
        baseRadios.first { $0.state == .on }?.tag ?? 16
    }

    private var useLength: Bool {
        lengthRadio.state == .on
    }

    private func formatValue(_ value: Int) -> String {
        let base = selectedBase
        switch base {
        case 8: return String(value, radix: 8)
        case 10: return String(value)
        default: return String(value, radix: 16, uppercase: true)
        }
    }

    @objc private func baseChanged(_ sender: NSButton) {
        for btn in baseRadios { btn.state = btn === sender ? .on : .off }
    }

    @objc private func modeChanged() {
        endField.isEnabled = endRadio.state == .on
        lengthField.isEnabled = lengthRadio.state == .on
    }

    @objc private func okTapped() {
        let base = selectedBase
        let startText = startField.stringValue.trimmingCharacters(in: .whitespaces)
        guard let start = Int(startText, radix: base), start >= 0 else {
            errorLabel.stringValue = "Invalid start offset."
            return
        }

        let end: Int
        if useLength {
            let lenText = lengthField.stringValue.trimmingCharacters(in: .whitespaces)
            guard let length = Int(lenText, radix: base), length > 0 else {
                errorLabel.stringValue = "Invalid length."
                return
            }
            end = start + length
        } else {
            let endText = endField.stringValue.trimmingCharacters(in: .whitespaces)
            guard let endVal = Int(endText, radix: base) else {
                errorLabel.stringValue = "Invalid end offset."
                return
            }
            end = endVal + 1
        }

        guard start < end else {
            errorLabel.stringValue = "Start must be before end."
            return
        }
        guard end <= maxOffset else {
            errorLabel.stringValue = "Range exceeds file size."
            return
        }

        dismiss(nil)
        blockDelegate?.selectBlock(range: start..<end)
    }

    @objc private func cancelTapped() {
        dismiss(nil)
    }
}
