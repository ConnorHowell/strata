// FindBar.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - FindBarDelegate

/// Delegate for find bar navigation actions.
public protocol FindBarDelegate: AnyObject {
    /// Called to navigate to the next result.
    func findBarDidRequestNext(_ bar: FindBar)
    /// Called to navigate to the previous result.
    func findBarDidRequestPrevious(_ bar: FindBar)
    /// Called when the user dismisses the find bar.
    func findBarDidDismiss(_ bar: FindBar)
}

// MARK: - FindBar

/// An inline results bar showing match count, current index, and prev/next buttons.
public final class FindBar: NSView {

    // MARK: - Public API

    /// The delegate for navigation actions.
    public weak var delegate: FindBarDelegate?

    /// Updates the displayed search term and result index.
    ///
    /// - Parameters:
    ///   - term: A short description of what was searched for.
    ///   - current: The 1-based index of the current result (0 if none).
    ///   - total: The total number of results (-1 if unknown).
    public func update(term: String, current: Int, total: Int) {
        if total == 0 {
            label.stringValue = "\"\(term)\" — No results"
            label.textColor = .secondaryLabelColor
        } else if total < 0 {
            label.stringValue = "\"\(term)\" — Match \(current)"
            label.textColor = .labelColor
        } else {
            label.stringValue = "\"\(term)\" — \(current) of \(total)"
            label.textColor = .labelColor
        }
        prevButton.isEnabled = current > 0 || total != 0
        nextButton.isEnabled = current > 0 || total != 0
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Private

    private let label = NSTextField(labelWithString: "")
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let closeButton = NSButton()

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = NSColor.separatorColor.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)

        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        configureButton(
            prevButton, symbol: "chevron.left",
            label: "Previous", action: #selector(prevTapped)
        )
        configureButton(
            nextButton, symbol: "chevron.right",
            label: "Next", action: #selector(nextTapped)
        )
        configureButton(
            closeButton, symbol: "xmark",
            label: "Close", action: #selector(closeTapped)
        )
        prevButton.isEnabled = false
        nextButton.isEnabled = false

        let stack = NSStackView(views: [
            label, prevButton, nextButton, closeButton,
        ])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: 12
            ),
            stack.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -8
            ),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    private func configureButton(
        _ button: NSButton, symbol: String,
        label: String, action: Selector
    ) {
        button.bezelStyle = .inline
        button.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: label
        )
        button.isBordered = true
        button.target = self
        button.action = action
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    @objc private func prevTapped() {
        delegate?.findBarDidRequestPrevious(self)
    }

    @objc private func nextTapped() {
        delegate?.findBarDidRequestNext(self)
    }

    @objc private func closeTapped() {
        delegate?.findBarDidDismiss(self)
    }
}
