// FindReplaceWindow.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - FindReplaceWindowController

/// Window controller for the HxD-style tabbed Find/Replace dialog.
final class FindReplaceWindowController: NSWindowController {

    // MARK: - Properties

    private let isReplace: Bool
    private weak var searchDelegate: FindReplacePanelDelegate?
    private let tabView = NSTabView()
    private lazy var directionAll = NSButton(
        radioButtonWithTitle: "All", target: self, action: #selector(directionTapped(_:))
    )
    private lazy var directionFwd = NSButton(
        radioButtonWithTitle: "Forward", target: self, action: #selector(directionTapped(_:))
    )
    private lazy var directionBwd = NSButton(
        radioButtonWithTitle: "Backward", target: self, action: #selector(directionTapped(_:))
    )
    private let textSearchField = NSTextField()
    private let textReplaceField = NSTextField()
    private let textEncodingPopup = NSPopUpButton()
    private let textCaseSensitive = NSButton(
        checkboxWithTitle: "Case sensitive", target: nil, action: nil
    )
    private let hexSearchField = NSTextField()
    private let hexReplaceField = NSTextField()
    private let intSearchField = NSTextField()
    private let intReplaceField = NSTextField()
    private let intBitWidthPopup = NSPopUpButton()
    private let intByteOrderPopup = NSPopUpButton()
    private let floatSearchField = NSTextField()
    private let floatReplaceField = NSTextField()
    private lazy var floatSingle = NSButton(
        radioButtonWithTitle: "Single (float32), 4 bytes", target: self, action: #selector(floatTypeTapped(_:))
    )
    private lazy var floatDouble = NSButton(
        radioButtonWithTitle: "Double (float64), 8 bytes", target: self, action: #selector(floatTypeTapped(_:))
    )

    // MARK: - Init

    init(isReplace: Bool, delegate: FindReplacePanelDelegate?) {
        self.isReplace = isReplace
        self.searchDelegate = delegate
        let height: CGFloat = isReplace ? 300 : 260
        let win = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = isReplace ? "Replace" : "Find"
        super.init(window: win)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Private

    private func setupUI() {
        guard let cv = window?.contentView else { return }
        tabView.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(tabView)
        tabView.addTabViewItem(buildTextTab())
        tabView.addTabViewItem(buildHexTab())
        tabView.addTabViewItem(buildIntTab())
        tabView.addTabViewItem(buildFloatTab())

        // Direction + buttons in a bottom bar
        let dirLabel = NSTextField(labelWithString: "Search direction:")
        dirLabel.translatesAutoresizingMaskIntoConstraints = false
        directionAll.translatesAutoresizingMaskIntoConstraints = false
        directionFwd.translatesAutoresizingMaskIntoConstraints = false
        directionBwd.translatesAutoresizingMaskIntoConstraints = false
        directionAll.state = .on

        let dirStack = NSStackView(views: [dirLabel, directionAll, directionFwd, directionBwd])
        dirStack.orientation = .horizontal
        dirStack.spacing = 8
        dirStack.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(dirStack)

        let okBtn = NSButton(title: "OK", target: self, action: #selector(okTapped))
        okBtn.bezelStyle = .rounded
        okBtn.keyEquivalent = "\r"
        let searchAllBtn = NSButton(
            title: "Search all", target: self, action: #selector(searchAllTapped)
        )
        searchAllBtn.bezelStyle = .rounded
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"

        let btnStack = NSStackView(views: [okBtn, searchAllBtn, cancelBtn])
        btnStack.orientation = .horizontal
        btnStack.spacing = 8
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(btnStack)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 8),
            tabView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -8),
            dirStack.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 8),
            dirStack.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            btnStack.topAnchor.constraint(equalTo: dirStack.bottomAnchor, constant: 12),
            btnStack.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -12),
            btnStack.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Tab Builders

    private func buildTextTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "text")
        item.label = "Text-string"
        let view = NSView()
        let sLabel = NSTextField(labelWithString: "Search for:")
        textSearchField.placeholderString = ""
        textSearchField.setAccessibilityIdentifier("findField")
        textEncodingPopup.addItems(withTitles: ["ASCII", "UTF-8", "UTF-16 LE", "UTF-16 BE"])
        let encLabel = NSTextField(labelWithString: "Text encoding:")
        var views: [NSView] = [sLabel, textSearchField, encLabel, textEncodingPopup, textCaseSensitive]
        if isReplace {
            let rLabel = NSTextField(labelWithString: "Replace:")
            views.append(contentsOf: [rLabel, textReplaceField])
        }
        for v in views { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        var c = fieldConstraints(search: sLabel, field: textSearchField, in: view)
        let anchor: NSLayoutAnchor<NSLayoutYAxisAnchor>
        if isReplace, let rLabel = views.first(where: { ($0 as? NSTextField)?.stringValue == "Replace:" }) {
            c += replaceConstraints(label: rLabel, field: textReplaceField, below: textSearchField, in: view)
            anchor = textReplaceField.bottomAnchor
        } else {
            anchor = textSearchField.bottomAnchor
        }
        c += [
            encLabel.topAnchor.constraint(equalTo: anchor, constant: 8),
            encLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            textEncodingPopup.centerYAnchor.constraint(equalTo: encLabel.centerYAnchor),
            textEncodingPopup.leadingAnchor.constraint(equalTo: encLabel.trailingAnchor, constant: 4),
            textCaseSensitive.topAnchor.constraint(equalTo: encLabel.bottomAnchor, constant: 4),
            textCaseSensitive.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
        ]
        NSLayoutConstraint.activate(c)
        item.view = view
        return item
    }

    private func buildHexTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "hex")
        item.label = "Hex-values"
        let view = NSView()
        let sLabel = NSTextField(labelWithString: "Search for:")
        hexSearchField.setAccessibilityIdentifier("hexFindField")
        var views: [NSView] = [sLabel, hexSearchField]
        if isReplace {
            let rLabel = NSTextField(labelWithString: "Replace:")
            views.append(contentsOf: [rLabel, hexReplaceField])
        }
        for v in views { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        var c = fieldConstraints(search: sLabel, field: hexSearchField, in: view)
        if isReplace, let rLabel = views.first(where: { ($0 as? NSTextField)?.stringValue == "Replace:" }) {
            c += replaceConstraints(label: rLabel, field: hexReplaceField, below: hexSearchField, in: view)
        }
        NSLayoutConstraint.activate(c)
        item.view = view
        return item
    }

    private func buildIntTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "int")
        item.label = "Integer number"
        let view = NSView()
        let sLabel = NSTextField(labelWithString: "Search for:")
        let wLabel = NSTextField(labelWithString: "Bitwidth:")
        intBitWidthPopup.addItems(withTitles: ["8 bit", "16 bit", "32 bit", "64 bit"])
        intBitWidthPopup.selectItem(at: 2)
        let oLabel = NSTextField(labelWithString: "Byte order:")
        intByteOrderPopup.addItems(withTitles: ["Little endian (Intel, AMD64, ...)", "Big endian"])
        var views: [NSView] = [sLabel, intSearchField, wLabel, intBitWidthPopup, oLabel, intByteOrderPopup]
        if isReplace {
            let rLabel = NSTextField(labelWithString: "Replace:")
            views.append(contentsOf: [rLabel, intReplaceField])
        }
        for v in views { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        var c = fieldConstraints(search: sLabel, field: intSearchField, in: view)
        let anchor: NSLayoutAnchor<NSLayoutYAxisAnchor>
        if isReplace, let rLabel = views.first(where: { ($0 as? NSTextField)?.stringValue == "Replace:" }) {
            c += replaceConstraints(label: rLabel, field: intReplaceField, below: intSearchField, in: view)
            anchor = intReplaceField.bottomAnchor
        } else {
            anchor = intSearchField.bottomAnchor
        }
        c += [
            wLabel.topAnchor.constraint(equalTo: anchor, constant: 8),
            wLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            intBitWidthPopup.centerYAnchor.constraint(equalTo: wLabel.centerYAnchor),
            intBitWidthPopup.leadingAnchor.constraint(equalTo: wLabel.trailingAnchor, constant: 4),
            oLabel.topAnchor.constraint(equalTo: wLabel.bottomAnchor, constant: 4),
            oLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            intByteOrderPopup.centerYAnchor.constraint(equalTo: oLabel.centerYAnchor),
            intByteOrderPopup.leadingAnchor.constraint(equalTo: oLabel.trailingAnchor, constant: 4),
        ]
        NSLayoutConstraint.activate(c)
        item.view = view
        return item
    }

    private func buildFloatTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "float")
        item.label = "Floating point"
        let view = NSView()
        let sLabel = NSTextField(labelWithString: "Search for:")
        let tLabel = NSTextField(labelWithString: "Floating point type:")
        floatSingle.state = .on
        var views: [NSView] = [sLabel, floatSearchField, tLabel, floatSingle, floatDouble]
        if isReplace {
            let rLabel = NSTextField(labelWithString: "Replace:")
            views.append(contentsOf: [rLabel, floatReplaceField])
        }
        for v in views { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        var c = fieldConstraints(search: sLabel, field: floatSearchField, in: view)
        let anchor: NSLayoutAnchor<NSLayoutYAxisAnchor>
        if isReplace, let rLabel = views.first(where: { ($0 as? NSTextField)?.stringValue == "Replace:" }) {
            c += replaceConstraints(label: rLabel, field: floatReplaceField, below: floatSearchField, in: view)
            anchor = floatReplaceField.bottomAnchor
        } else {
            anchor = floatSearchField.bottomAnchor
        }
        c += [
            tLabel.topAnchor.constraint(equalTo: anchor, constant: 8),
            tLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            floatSingle.topAnchor.constraint(equalTo: tLabel.bottomAnchor, constant: 4),
            floatSingle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            floatDouble.topAnchor.constraint(equalTo: floatSingle.bottomAnchor, constant: 2),
            floatDouble.leadingAnchor.constraint(equalTo: floatSingle.leadingAnchor),
        ]
        NSLayoutConstraint.activate(c)
        item.view = view
        return item
    }

    // MARK: - Constraint Helpers

    private func fieldConstraints(
        search label: NSView, field: NSTextField, in view: NSView
    ) -> [NSLayoutConstraint] {
        [
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ]
    }

    private func replaceConstraints(
        label: NSView, field: NSTextField, below: NSView, in view: NSView
    ) -> [NSLayoutConstraint] {
        [
            label.topAnchor.constraint(equalTo: below.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            field.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ]
    }

    // MARK: - Actions

    @objc private func okTapped() {
        guard let pattern = buildPattern() else { showNoInput(); return }
        window?.sheetParent?.endSheet(window!, returnCode: .OK)
        searchDelegate?.findReplacePanel(FindReplacePanel(frame: .zero), didSearchFor: pattern)
    }

    @objc private func searchAllTapped() {
        guard let pattern = buildPattern() else { showNoInput(); return }
        let allDir = SearchPattern(
            mode: pattern.mode, data: pattern.data, mask: pattern.mask,
            direction: .all, caseSensitive: pattern.caseSensitive
        )
        window?.sheetParent?.endSheet(window!, returnCode: .OK)
        searchDelegate?.findReplacePanel(FindReplacePanel(frame: .zero), didSearchFor: allDir)
    }

    @objc private func cancelTapped() {
        window?.sheetParent?.endSheet(window!, returnCode: .cancel)
    }

    @objc private func directionTapped(_ sender: NSButton) {
        for btn in [directionAll, directionFwd, directionBwd] {
            btn.state = btn === sender ? .on : .off
        }
    }

    @objc private func floatTypeTapped(_ sender: NSButton) {
        floatSingle.state = sender === floatSingle ? .on : .off
        floatDouble.state = sender === floatDouble ? .on : .off
    }

    // MARK: - Pattern Building

    private func selectedDirection() -> SearchDirection {
        if directionBwd.state == .on { return .backward }
        if directionFwd.state == .on { return .forward }
        return .all
    }

    private func buildPattern() -> SearchPattern? {
        let tabID = tabView.selectedTabViewItem?.identifier as? String ?? "text"
        switch tabID {
        case "text": return buildTextPattern()
        case "hex": return buildHexPattern()
        case "int": return buildIntPattern()
        case "float": return buildFloatPattern()
        default: return nil
        }
    }

    private func buildTextPattern() -> SearchPattern? {
        let text = textSearchField.stringValue
        guard !text.isEmpty else { return nil }
        let isCaseSensitive = textCaseSensitive.state == .on
        let encoding: String.Encoding
        switch textEncodingPopup.indexOfSelectedItem {
        case 0: encoding = .ascii
        case 1: encoding = .utf8
        case 2: encoding = .utf16LittleEndian
        case 3: encoding = .utf16BigEndian
        default: encoding = .utf8
        }
        guard let data = text.data(using: encoding) else { return nil }
        return SearchPattern(
            mode: .textString, data: data, mask: nil,
            direction: selectedDirection(), caseSensitive: isCaseSensitive
        )
    }

    private func buildHexPattern() -> SearchPattern? {
        let text = hexSearchField.stringValue
        guard !text.isEmpty, let data = FindReplacePanel.parseHexPattern(text) else { return nil }
        return SearchPattern(mode: .hexValues, data: data, mask: nil, direction: selectedDirection())
    }

    private func buildIntPattern() -> SearchPattern? {
        let text = intSearchField.stringValue
        guard !text.isEmpty, let value = Int64(text) else { return nil }
        let le = intByteOrderPopup.indexOfSelectedItem == 0
        var data = Data()
        switch intBitWidthPopup.indexOfSelectedItem {
        case 0:
            var val = Int8(clamping: value)
            data.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        case 1:
            var val = le ? Int16(clamping: value).littleEndian : Int16(clamping: value).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        case 2:
            var val = le ? Int32(clamping: value).littleEndian : Int32(clamping: value).bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        case 3:
            var val = le ? value.littleEndian : value.bigEndian
            data.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        default: return nil
        }
        return SearchPattern(mode: .integerNumber, data: data, mask: nil, direction: selectedDirection())
    }

    private func buildFloatPattern() -> SearchPattern? {
        let text = floatSearchField.stringValue
        guard !text.isEmpty, let dblVal = Double(text) else { return nil }
        var data = Data()
        if floatSingle.state == .on {
            var val = Float(dblVal)
            data.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        } else {
            var val = dblVal
            data.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        }
        return SearchPattern(mode: .floatingPoint, data: data, mask: nil, direction: selectedDirection())
    }

    private func showNoInput() {
        guard let win = window else { return }
        let alert = NSAlert()
        alert.messageText = "No search term entered."
        alert.informativeText = "Please enter a value to search for."
        alert.alertStyle = .warning
        alert.beginSheetModal(for: win)
    }
}
