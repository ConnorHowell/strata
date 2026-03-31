// TabBar.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - TabBarDelegate

/// Delegate for tab bar interaction events.
public protocol TabBarDelegate: AnyObject {
    /// Called when a tab is selected.
    func tabBar(_ tabBar: TabBar, didSelectTabAt index: Int)
    /// Called when a tab's close button is clicked.
    func tabBar(_ tabBar: TabBar, didCloseTabAt index: Int)
}

// MARK: - TabBar

/// A horizontal tab bar for switching between open document sessions.
public final class TabBar: NSView {

    // MARK: - Public API

    /// The delegate for tab interaction events.
    public weak var delegate: TabBarDelegate?

    /// Initializes the tab bar.
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        setAccessibilityIdentifier("tabBar")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Updates the tab bar with new titles and active index.
    ///
    /// - Parameters:
    ///   - titles: The tab titles to display.
    ///   - activeIndex: The index of the currently active tab.
    public func update(titles: [String], activeIndex: Int) {
        subviews.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()

        var xOffset: CGFloat = 0
        let tabHeight = bounds.height

        for (index, title) in titles.enumerated() {
            let isActive = index == activeIndex
            let tabWidth: CGFloat = min(180, max(100, CGFloat(title.count) * 8 + 40))
            let tab = TabButton(frame: NSRect(x: xOffset, y: 0, width: tabWidth, height: tabHeight))
            tab.title = title
            tab.isActive = isActive
            tab.tabIndex = index
            tab.target = self
            tab.action = #selector(tabClicked(_:))
            tab.closeAction = { [weak self] in
                guard let self else { return }
                self.delegate?.tabBar(self, didCloseTabAt: index)
            }
            addSubview(tab)
            tabButtons.append(tab)
            xOffset += tabWidth + 1
        }
    }

    // MARK: - Private

    private var tabButtons: [TabButton] = []

    @objc private func tabClicked(_ sender: TabButton) {
        delegate?.tabBar(self, didSelectTabAt: sender.tabIndex)
    }
}

// MARK: - TabButton

/// An individual tab button within the tab bar.
private final class TabButton: NSView {

    // MARK: - Public API

    /// The displayed tab title.
    var title: String = "" { didSet { titleLabel.stringValue = title } }

    /// Whether this tab is currently active.
    var isActive: Bool = false { didSet { needsDisplay = true } }

    /// The target for click actions.
    weak var target: AnyObject?

    /// The action selector for clicks.
    var action: Selector?

    /// Closure called when the close button is clicked.
    var closeAction: (() -> Void)?

    /// The tab index.
    var tabIndex: Int = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        let bgColor = isActive ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.clear
        bgColor.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        path.fill()

        if isActive {
            NSColor.controlAccentColor.setFill()
            let indicator = NSRect(x: 0, y: bounds.height - 2, width: bounds.width, height: 2)
            NSBezierPath(rect: indicator).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let target, let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    // MARK: - Private

    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()

    private func setupViews() {
        titleLabel.font = .systemFont(ofSize: 11)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close tab")
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    @objc private func closeClicked() {
        closeAction?()
    }
}
