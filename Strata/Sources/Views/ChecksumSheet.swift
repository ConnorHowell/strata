// ChecksumSheet.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - ChecksumRegion

/// Specifies which region of data to compute checksums over.
public enum ChecksumRegion {
    /// The current selection only.
    case selection
    /// The entire file.
    case entireFile
}

// MARK: - ChecksumSheetDelegate

/// Delegate for receiving checksum configuration from the sheet.
public protocol ChecksumSheetDelegate: AnyObject {
    /// Called when the user confirms their checksum selections.
    ///
    /// - Parameters:
    ///   - sheet: The presenting sheet.
    ///   - types: The selected checksum algorithms.
    ///   - region: Whether to compute over selection or entire file.
    ///   - compareHex: An optional hex string to compare results against.
    func checksumSheet(
        _ sheet: ChecksumSheet,
        didSelectTypes types: [ChecksumType],
        region: ChecksumRegion,
        compareHex: String?
    )
}

// MARK: - ChecksumSheet

/// A sheet for selecting checksum algorithms, region, and optional comparison value.
public final class ChecksumSheet: NSViewController {

    // MARK: - Public API

    /// The delegate to receive configuration.
    public weak var sheetDelegate: ChecksumSheetDelegate?

    /// Whether a selection exists in the hex view.
    public var hasSelection: Bool = false

    override public func loadView() {
        view = NSView(frame: .zero)
        setupViews()
    }

    // MARK: - Private

    private var checkboxes: [(ChecksumType, NSButton)] = []
    private var regionRadios: [NSButton] = []
    private let compareField = NSTextField()
    private let compareCheck = NSButton(checkboxWithTitle: "Compare with checksum:",
                                        target: nil, action: nil)

    private func setupViews() {
        let margin: CGFloat = 16
        let titleLabel = makeTitleLabel()
        let algoLabel = makeAlgoLabel()
        let scrollView = makeAlgorithmList()
        let regionBox = makeRegionBox()
        setupCompareControls()
        let buttonStack = makeButtonStack()

        for sub in [
            titleLabel, algoLabel, scrollView, regionBox,
            compareCheck, compareField, buttonStack,
        ] as [NSView] {
            view.addSubview(sub)
        }

        activateConstraints(
            margin: margin,
            views: [titleLabel, algoLabel, scrollView, regionBox, buttonStack]
        )
    }

    private func makeTitleLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Generate checksums")
        label.font = .boldSystemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeAlgoLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Available algorithms:")
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeAlgorithmList() -> NSScrollView {
        let listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 4

        for type in ChecksumType.allCases {
            let cb = NSButton(checkboxWithTitle: type.rawValue,
                              target: nil, action: nil)
            cb.state = defaultChecked(type) ? .on : .off
            cb.font = .systemFont(ofSize: 12)
            listStack.addArrangedSubview(cb)
            checkboxes.append((type, cb))
        }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        let clipView = NSClipView()
        clipView.documentView = listStack
        scrollView.contentView = clipView
        listStack.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
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

    private func setupCompareControls() {
        compareCheck.target = self
        compareCheck.action = #selector(compareToggled)
        compareCheck.translatesAutoresizingMaskIntoConstraints = false
        compareField.placeholderString = "Expected hex value"
        compareField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        compareField.isEnabled = false
        compareField.translatesAutoresizingMaskIntoConstraints = false
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

    private func activateConstraints(
        margin: CGFloat, views: [NSView]
    ) {
        let titleLabel = views[0]
        let algoLabel = views[1]
        let scrollView = views[2]
        let regionBox = views[3]
        let buttonStack = views[4]

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 340),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            algoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            algoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            scrollView.topAnchor.constraint(equalTo: algoLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            scrollView.heightAnchor.constraint(equalToConstant: 160),
            regionBox.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            regionBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            regionBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            compareCheck.topAnchor.constraint(equalTo: regionBox.bottomAnchor, constant: 10),
            compareCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            compareField.topAnchor.constraint(equalTo: compareCheck.bottomAnchor, constant: 4),
            compareField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            compareField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.topAnchor.constraint(equalTo: compareField.bottomAnchor, constant: 12),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    private func defaultChecked(_ type: ChecksumType) -> Bool {
        switch type {
        case .crc32, .md5, .sha1, .sha256: return true
        default: return false
        }
    }

    @objc private func regionChanged(_ sender: NSButton) {
        for btn in regionRadios { btn.state = btn === sender ? .on : .off }
    }

    @objc private func compareToggled() {
        compareField.isEnabled = compareCheck.state == .on
    }

    @objc private func okTapped() {
        let selected = checkboxes.compactMap { (type, cb) -> ChecksumType? in
            cb.state == .on ? type : nil
        }
        guard !selected.isEmpty else { return }

        let region: ChecksumRegion = regionRadios.first(where: { $0.state == .on })?.tag == 0
            ? .selection : .entireFile

        let compare: String? = compareCheck.state == .on
            ? compareField.stringValue.trimmingCharacters(in: .whitespaces)
            : nil

        let delegate = sheetDelegate
        dismiss(nil)
        delegate?.checksumSheet(self, didSelectTypes: selected,
                                region: region, compareHex: compare)
    }

    @objc private func cancelTapped() {
        dismiss(nil)
    }
}
