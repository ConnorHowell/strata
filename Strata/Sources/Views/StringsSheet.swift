// StringsSheet.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - StringsSheetDelegate

/// Delegate for receiving strings scan configuration.
public protocol StringsSheetDelegate: AnyObject {
    /// Called when the user confirms the strings scan configuration.
    ///
    /// - Parameters:
    ///   - sheet: The presenting sheet.
    ///   - minLength: Minimum character length for string detection.
    ///   - encodings: Which encodings to scan.
    ///   - region: Whether to scan selection or entire file.
    func stringsSheet(
        _ sheet: StringsSheet,
        didConfigure minLength: Int,
        encodings: Set<StringMatchEncoding>,
        region: ChecksumRegion
    )
}

// MARK: - StringsSheet

/// A sheet for configuring string extraction parameters.
public final class StringsSheet: NSViewController {

    // MARK: - Public API

    /// The delegate to receive configuration.
    public weak var sheetDelegate: StringsSheetDelegate?

    /// Whether a selection exists in the hex view.
    public var hasSelection: Bool = false

    override public func loadView() {
        view = NSView(frame: .zero)
        setupViews()
    }

    // MARK: - Private

    private let minLengthField = NSTextField()
    private let minLengthStepper = NSStepper()
    private var encodingChecks: [(StringMatchEncoding, NSButton)] = []
    private var regionRadios: [NSButton] = []

    private func setupViews() {
        let margin: CGFloat = 16
        let titleLabel = makeTitleLabel()
        let minStack = makeMinLengthRow()
        let encBox = makeEncodingBox()
        let regionBox = makeRegionBox()
        let buttonStack = makeButtonStack()

        for sub in [titleLabel, minStack, encBox, regionBox, buttonStack] as [NSView] {
            view.addSubview(sub)
        }

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 300),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            minStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            minStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            minLengthField.widthAnchor.constraint(equalToConstant: 50),
            encBox.topAnchor.constraint(equalTo: minStack.bottomAnchor, constant: 12),
            encBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            encBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            regionBox.topAnchor.constraint(equalTo: encBox.bottomAnchor, constant: 10),
            regionBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            regionBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.topAnchor.constraint(equalTo: regionBox.bottomAnchor, constant: 12),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private func makeTitleLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Extract Strings")
        label.font = .boldSystemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeMinLengthRow() -> NSStackView {
        let minLabel = NSTextField(labelWithString: "Minimum length:")
        minLabel.font = .systemFont(ofSize: 12)
        minLengthField.integerValue = 4
        minLengthField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        minLengthStepper.minValue = 1
        minLengthStepper.maxValue = 256
        minLengthStepper.integerValue = 4
        minLengthStepper.target = self
        minLengthStepper.action = #selector(stepperChanged)

        let stack = NSStackView(views: [minLabel, minLengthField, minLengthStepper])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeEncodingBox() -> NSBox {
        let box = NSBox()
        box.title = "Encodings"
        box.titlePosition = .atTop
        box.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        for enc in StringMatchEncoding.allCases {
            let cb = NSButton(checkboxWithTitle: enc.rawValue,
                              target: nil, action: nil)
            cb.state = enc == .ascii ? .on : .off
            cb.font = .systemFont(ofSize: 12)
            stack.addArrangedSubview(cb)
            encodingChecks.append((enc, cb))
        }

        if let content = box.contentView {
            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -4),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -4),
            ])
        }
        return box
    }

    private func makeRegionBox() -> NSBox {
        let box = NSBox()
        box.title = "Region"
        box.titlePosition = .atTop
        box.translatesAutoresizingMaskIntoConstraints = false

        let selRadio = NSButton(
            radioButtonWithTitle: "Selection",
            target: self, action: #selector(regionChanged)
        )
        let fileRadio = NSButton(
            radioButtonWithTitle: "Entire file",
            target: self, action: #selector(regionChanged)
        )
        selRadio.tag = 0
        fileRadio.tag = 1
        selRadio.isEnabled = hasSelection
        fileRadio.state = .on
        if hasSelection { selRadio.state = .on; fileRadio.state = .off }
        regionRadios = [selRadio, fileRadio]

        let stack = NSStackView(views: [selRadio, fileRadio])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let content = box.contentView {
            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 4),
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -4),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -4),
            ])
        }
        return box
    }

    private func makeButtonStack() -> NSStackView {
        let okButton = NSButton(title: "OK", target: self, action: #selector(okTapped))
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Cancel", target: self,
                                     action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        let stack = NSStackView(views: [cancelButton, okButton])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    @objc private func stepperChanged() {
        minLengthField.integerValue = minLengthStepper.integerValue
    }

    @objc private func regionChanged(_ sender: NSButton) {
        for btn in regionRadios { btn.state = btn === sender ? .on : .off }
    }

    @objc private func okTapped() {
        let minLen = max(1, minLengthField.integerValue)
        var encodings = Set<StringMatchEncoding>()
        for (enc, cb) in encodingChecks where cb.state == .on {
            encodings.insert(enc)
        }
        guard !encodings.isEmpty else { return }

        let region: ChecksumRegion = regionRadios.first(where: { $0.state == .on })?.tag == 0
            ? .selection : .entireFile

        let delegate = sheetDelegate
        dismiss(nil)
        delegate?.stringsSheet(self, didConfigure: minLen,
                               encodings: encodings, region: region)
    }

    @objc private func cancelTapped() {
        dismiss(nil)
    }
}
