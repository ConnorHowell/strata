// AppDelegate+Menus.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - Menu Builders

extension AppDelegate {

    /// Shows the About panel with author credits.
    @objc func showAboutPanel() {
        let credits = NSMutableAttributedString()
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
        ]
        credits.append(NSAttributedString(
            string: "Created by Connor Howell\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]
        ))
        credits.append(NSAttributedString(
            string: "\nA native macOS hex editor inspired by HxD.\n",
            attributes: bodyAttrs
        ))
        credits.append(NSAttributedString(
            string: "Licensed under the MIT License.",
            attributes: bodyAttrs
        ))
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
        ])
    }

    func buildAppMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Strata")
        menu.addItem(
            withTitle: "About Strata",
            action: #selector(showAboutPanel),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Strata",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.submenu = menu
        return item
    }

    func buildFileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "New", action: #selector(newFileAction), keyEquivalent: "n")
        menu.addItem(withTitle: "Open…", action: #selector(openFileAction), keyEquivalent: "o")
        let recentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        recentItem.submenu = buildRecentFilesMenu()
        menu.addItem(recentItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Save", action: #selector(saveFileAction), keyEquivalent: "s")
        let saveAs = menu.addItem(
            withTitle: "Save As…",
            action: #selector(saveFileAsAction),
            keyEquivalent: "S"
        )
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close Tab", action: #selector(closeTabAction), keyEquivalent: "w")
        item.submenu = menu
        return item
    }

    func buildRecentFilesMenu() -> NSMenu {
        let menu = NSMenu(title: "Open Recent")
        if recentFileURLs.isEmpty {
            let mi = NSMenuItem(title: "No Recent Files", action: nil, keyEquivalent: "")
            mi.isEnabled = false
            menu.addItem(mi)
        } else {
            for (idx, url) in recentFileURLs.enumerated() {
                let mi = NSMenuItem(
                    title: url.lastPathComponent,
                    action: #selector(openRecentFile(_:)),
                    keyEquivalent: ""
                )
                mi.tag = idx
                mi.toolTip = url.path
                menu.addItem(mi)
            }
            menu.addItem(.separator())
            menu.addItem(
                withTitle: "Clear Recent Files",
                action: #selector(clearRecentFiles),
                keyEquivalent: ""
            )
        }
        return menu
    }

    func buildEditMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: #selector(undoAction), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: #selector(redoAction), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(cutAction), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(copyAction), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(pasteAction), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(selectAllAction), keyEquivalent: "a")
        let selBlock = menu.addItem(
            withTitle: "Select Block…",
            action: #selector(showSelectBlockAction),
            keyEquivalent: "e"
        )
        selBlock.keyEquivalentModifierMask = [.command]
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Fill Selection…",
            action: #selector(fillSelectionAction),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(withTitle: "Find…", action: #selector(showFindAction), keyEquivalent: "f")
        menu.addItem(withTitle: "Replace…", action: #selector(showReplaceAction), keyEquivalent: "h")
        menu.addItem(withTitle: "Go To Offset…", action: #selector(showGoToAction), keyEquivalent: "g")
        item.submenu = menu
        return item
    }

    func buildViewMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")
        menu.addItem(
            withTitle: "Toggle Checksum Panel",
            action: #selector(toggleChecksumPanelAction),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Toggle Insert Mode",
            action: #selector(toggleInsertModeAction),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(buildOffsetBaseSubmenu())
        menu.addItem(buildEncodingSubmenu())
        menu.addItem(buildBytesPerRowSubmenu())
        menu.addItem(buildByteGroupingSubmenu())
        item.submenu = menu
        return item
    }

    func buildToolsMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Tools")
        menu.addItem(
            withTitle: "Compare Files…",
            action: #selector(compareToolAction),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Byte Statistics…",
            action: #selector(byteStatisticsAction),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Concatenate Files…",
            action: #selector(concatenateFilesAction),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Split File…",
            action: #selector(splitFileAction),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Import Intel HEX…",
            action: #selector(importIntelHexAction),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Import S-Record…",
            action: #selector(importSRecordAction),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Export Intel HEX…",
            action: #selector(exportIntelHexAction),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Export S-Record…",
            action: #selector(exportSRecordAction),
            keyEquivalent: ""
        )
        item.submenu = menu
        return item
    }

    // MARK: - Private Submenu Builders

    private func buildOffsetBaseSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Offset Base", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Offset Base")
        for base in OffsetBase.allCases {
            let mi = NSMenuItem(
                title: base.rawValue,
                action: #selector(setOffsetBase(_:)),
                keyEquivalent: ""
            )
            mi.representedObject = base
            menu.addItem(mi)
        }
        item.submenu = menu
        return item
    }

    private func buildEncodingSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Character Encoding", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Character Encoding")
        for enc in TextEncoding.allCases {
            let mi = NSMenuItem(
                title: enc.rawValue,
                action: #selector(setTextEncoding(_:)),
                keyEquivalent: ""
            )
            mi.representedObject = enc
            menu.addItem(mi)
        }
        item.submenu = menu
        return item
    }

    private func buildBytesPerRowSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Bytes Per Row", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Bytes Per Row")
        for count in [8, 16, 24, 32, 48, 64] {
            let mi = NSMenuItem(
                title: "\(count)",
                action: #selector(setBytesPerRow(_:)),
                keyEquivalent: ""
            )
            mi.tag = count
            menu.addItem(mi)
        }
        item.submenu = menu
        return item
    }

    private func buildByteGroupingSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Byte Grouping", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Byte Grouping")
        for size in [1, 2, 4, 8, 16] {
            let mi = NSMenuItem(
                title: "\(size)",
                action: #selector(setByteGrouping(_:)),
                keyEquivalent: ""
            )
            mi.tag = size
            menu.addItem(mi)
        }
        item.submenu = menu
        return item
    }
}
