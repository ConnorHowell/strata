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

/// A sheet view controller for navigating to a specific byte offset,
/// matching HxD's Go To dialog with hex/dec/oct and relative-to options.
public final class GoToOffsetSheet: NSViewController {

    // MARK: - Public API

    /// The delegate to receive navigation requests.
    public weak var offsetDelegate: GoToOffsetDelegate?

    /// The maximum valid offset for validation.
    public var maxOffset: Int = 0

    /// The current cursor offset, used for relative navigation.
    public var currentOffset: Int = 0

    override public func loadView() {
        view = NSView(frame: .zero)
        setupViews()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        offsetField.setAccessibilityIdentifier("goToOffsetField")
    }

    // MARK: - Private

    private let offsetField = NSTextField()
    private let errorLabel = NSTextField(labelWithString: "")
    private var baseRadios: [NSButton] = []
    private var relRadios: [NSButton] = []

    private func setupViews() {
        let margin: CGFloat = 16

        // Offset label and field
        let offsetLabel = NSTextField(labelWithString: "Offset:")
        offsetLabel.font = .systemFont(ofSize: 12)
        offsetLabel.translatesAutoresizingMaskIntoConstraints = false

        offsetField.placeholderString = "0"
        offsetField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        offsetField.translatesAutoresizingMaskIntoConstraints = false

        // Base radio buttons: hex / dec / oct
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

        // Relative-to group box
        let relBox = NSBox()
        relBox.title = "Offset relative to"
        relBox.titlePosition = .atTop
        relBox.translatesAutoresizingMaskIntoConstraints = false

        let beginRadio = NSButton(
            radioButtonWithTitle: "begin", target: self, action: #selector(relativeChanged)
        )
        let currentRadio = NSButton(
            radioButtonWithTitle: "current offset",
            target: self,
            action: #selector(relativeChanged)
        )
        let endRadio = NSButton(
            radioButtonWithTitle: "end (backwards)",
            target: self,
            action: #selector(relativeChanged)
        )
        beginRadio.state = .on
        beginRadio.tag = 0
        currentRadio.tag = 1
        endRadio.tag = 2
        relRadios = [beginRadio, currentRadio, endRadio]

        let relStack = NSStackView(views: [beginRadio, currentRadio, endRadio])
        relStack.orientation = .vertical
        relStack.alignment = .leading
        relStack.spacing = 4
        relStack.translatesAutoresizingMaskIntoConstraints = false

        guard let boxContent = relBox.contentView else { return }
        boxContent.addSubview(relStack)
        NSLayoutConstraint.activate([
            relStack.topAnchor.constraint(equalTo: boxContent.topAnchor, constant: 4),
            relStack.leadingAnchor.constraint(equalTo: boxContent.leadingAnchor, constant: 4),
            relStack.trailingAnchor.constraint(equalTo: boxContent.trailingAnchor, constant: -4),
            relStack.bottomAnchor.constraint(equalTo: boxContent.bottomAnchor, constant: -4),
        ])

        // Error label
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        let okButton = NSButton(title: "OK", target: self, action: #selector(okTapped))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.setAccessibilityIdentifier("goToOK")

        let cancelButton = NSButton(
            title: "Cancel", target: self, action: #selector(cancelTapped)
        )
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let buttonStack = NSStackView(views: [cancelButton, okButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        for sub in [
            offsetLabel, offsetField, baseStack,
            relBox, errorLabel, buttonStack,
        ] as [NSView] {
            view.addSubview(sub)
        }

        activateLayoutConstraints(
            margin: margin, offsetLabel: offsetLabel,
            baseStack: baseStack, relBox: relBox, buttonStack: buttonStack
        )
    }

    private func activateLayoutConstraints(
        margin: CGFloat, offsetLabel: NSView,
        baseStack: NSView, relBox: NSView, buttonStack: NSView
    ) {
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 300),

            offsetLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            offsetLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            offsetField.topAnchor.constraint(equalTo: offsetLabel.bottomAnchor, constant: 4),
            offsetField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            offsetField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            baseStack.topAnchor.constraint(equalTo: offsetField.bottomAnchor, constant: 10),
            baseStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            relBox.topAnchor.constraint(equalTo: baseStack.bottomAnchor, constant: 12),
            relBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            relBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            errorLabel.topAnchor.constraint(equalTo: relBox.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            buttonStack.topAnchor.constraint(
                greaterThanOrEqualTo: errorLabel.bottomAnchor, constant: 8
            ),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private var selectedBase: Int {
        baseRadios.first { $0.state == .on }?.tag ?? 16
    }

    private var selectedRelative: Int {
        relRadios.first { $0.state == .on }?.tag ?? 0
    }

    @objc private func baseChanged(_ sender: NSButton) {
        for btn in baseRadios { btn.state = btn === sender ? .on : .off }
    }

    @objc private func relativeChanged(_ sender: NSButton) {
        for btn in relRadios { btn.state = btn === sender ? .on : .off }
    }

    @objc private func okTapped() {
        let text = offsetField.stringValue.trimmingCharacters(in: .whitespaces)
        guard let value = Int(text, radix: selectedBase) else {
            errorLabel.stringValue = "Invalid offset format."
            return
        }

        let resolved: Int
        switch selectedRelative {
        case 1: resolved = currentOffset + value
        case 2: resolved = maxOffset - value
        default: resolved = value
        }

        guard resolved >= 0, resolved <= maxOffset else {
            errorLabel.stringValue = "Offset out of range (0–\(String(format: "0x%X", maxOffset)))."
            return
        }
        dismiss(nil)
        offsetDelegate?.goToOffset(resolved)
    }

    @objc private func cancelTapped() {
        dismiss(nil)
    }
}
