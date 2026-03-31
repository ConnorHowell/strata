// KeyBindings.swift
// Strata - macOS Hex Editor

import AppKit

// MARK: - KeyAction

/// All bindable actions in the hex editor.
public enum KeyAction: String, CaseIterable {
    /// Open a file.
    case openFile
    /// Save the current file.
    case save
    /// Save the current file to a new location.
    case saveAs
    /// Open the Find panel.
    case find
    /// Open the Find & Replace panel.
    case replace
    /// Open the Go To Offset sheet.
    case goToOffset
    /// Undo the last edit.
    case undo
    /// Redo the last undone edit.
    case redo
    /// Select all bytes.
    case selectAll
    /// Close the active tab.
    case closeTab
    /// Copy the selection to the clipboard.
    case copy
    /// Cut the selection to the clipboard.
    case cut
    /// Paste from the clipboard.
    case paste
    /// Toggle focus between hex and ASCII panes.
    case togglePaneFocus
    /// Toggle between insert and overwrite modes.
    case toggleInsertMode
    /// Scroll up one page.
    case pageUp
    /// Scroll down one page.
    case pageDown
    /// Move to the beginning of the current line.
    case home
    /// Move to the end of the current line.
    case end
    /// Move to the beginning of the document.
    case documentStart
    /// Move to the end of the document.
    case documentEnd
    /// Set a numbered bookmark (0-9) at the current cursor position.
    case setBookmark0, setBookmark1, setBookmark2, setBookmark3, setBookmark4
    /// Set a numbered bookmark (5-9) at the current cursor position.
    case setBookmark5, setBookmark6, setBookmark7, setBookmark8, setBookmark9
    /// Jump to a numbered bookmark (0-9).
    case goToBookmark0, goToBookmark1, goToBookmark2, goToBookmark3, goToBookmark4
    /// Jump to a numbered bookmark (5-9).
    case goToBookmark5, goToBookmark6, goToBookmark7, goToBookmark8, goToBookmark9
    /// Fill the selected range with a byte pattern.
    case fillSelection
    /// Create a new tab.
    case newFile
}

// MARK: - KeyCombination

/// A keyboard shortcut consisting of a virtual key code and modifier flags.
public struct KeyCombination: Hashable {
    /// The virtual key code.
    public let keyCode: UInt16
    /// The modifier flags (command, shift, etc.).
    public let modifierFlags: NSEvent.ModifierFlags

    /// Creates a key combination.
    ///
    /// - Parameters:
    ///   - keyCode: The virtual key code.
    ///   - modifierFlags: The modifier flags.
    public init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags = []) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags.intersection([.command, .shift, .option, .control])
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifierFlags.rawValue)
    }

    public static func == (lhs: KeyCombination, rhs: KeyCombination) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifierFlags == rhs.modifierFlags
    }
}

// MARK: - VirtualKeyCode

private enum VirtualKeyCode {
    static let a: UInt16 = 0x00
    static let s: UInt16 = 0x01
    static let f: UInt16 = 0x03
    static let h: UInt16 = 0x04
    static let g: UInt16 = 0x05
    static let z: UInt16 = 0x06
    static let x: UInt16 = 0x07
    static let c: UInt16 = 0x08
    static let v: UInt16 = 0x09
    static let n: UInt16 = 0x2D
    static let w: UInt16 = 0x0D
    static let o: UInt16 = 0x1F
    static let tab: UInt16 = 0x30
    static let help: UInt16 = 0x72
    static let home: UInt16 = 0x73
    static let pageUp: UInt16 = 0x74
    static let end: UInt16 = 0x77
    static let pageDown: UInt16 = 0x79
    // Number keys 0-9
    static let key0: UInt16 = 0x1D
    static let key1: UInt16 = 0x12
    static let key2: UInt16 = 0x13
    static let key3: UInt16 = 0x14
    static let key4: UInt16 = 0x15
    static let key5: UInt16 = 0x17
    static let key6: UInt16 = 0x16
    static let key7: UInt16 = 0x1A
    static let key8: UInt16 = 0x1C
    static let key9: UInt16 = 0x19
}

// MARK: - KeyBindingMap

/// Single source of truth for all keyboard shortcuts. Never hardcode key checks elsewhere.
public enum KeyBindingMap {

    // MARK: - Public API

    /// The current active key bindings.
    public static var bindings: [KeyCombination: KeyAction] = defaultBindings()

    /// Returns the default HxD-like key bindings.
    ///
    /// - Returns: A dictionary mapping key combinations to actions.
    public static func defaultBindings() -> [KeyCombination: KeyAction] {
        let cmd = NSEvent.ModifierFlags.command
        let cmdShift: NSEvent.ModifierFlags = [.command, .shift]

        let ctrlShift: NSEvent.ModifierFlags = [.control, .shift]
        let ctrl = NSEvent.ModifierFlags.control
        let numKeys: [UInt16] = [
            VirtualKeyCode.key0, VirtualKeyCode.key1, VirtualKeyCode.key2,
            VirtualKeyCode.key3, VirtualKeyCode.key4, VirtualKeyCode.key5,
            VirtualKeyCode.key6, VirtualKeyCode.key7, VirtualKeyCode.key8,
            VirtualKeyCode.key9,
        ]
        let setActions: [KeyAction] = [
            .setBookmark0, .setBookmark1, .setBookmark2, .setBookmark3, .setBookmark4,
            .setBookmark5, .setBookmark6, .setBookmark7, .setBookmark8, .setBookmark9,
        ]
        let goActions: [KeyAction] = [
            .goToBookmark0, .goToBookmark1, .goToBookmark2, .goToBookmark3, .goToBookmark4,
            .goToBookmark5, .goToBookmark6, .goToBookmark7, .goToBookmark8, .goToBookmark9,
        ]

        var map: [KeyCombination: KeyAction] = [
            KeyCombination(keyCode: VirtualKeyCode.n, modifierFlags: cmd): .newFile,
            KeyCombination(keyCode: VirtualKeyCode.o, modifierFlags: cmd): .openFile,
            KeyCombination(keyCode: VirtualKeyCode.s, modifierFlags: cmd): .save,
            KeyCombination(keyCode: VirtualKeyCode.s, modifierFlags: cmdShift): .saveAs,
            KeyCombination(keyCode: VirtualKeyCode.f, modifierFlags: cmd): .find,
            KeyCombination(keyCode: VirtualKeyCode.h, modifierFlags: cmd): .replace,
            KeyCombination(keyCode: VirtualKeyCode.g, modifierFlags: cmd): .goToOffset,
            KeyCombination(keyCode: VirtualKeyCode.z, modifierFlags: cmd): .undo,
            KeyCombination(keyCode: VirtualKeyCode.z, modifierFlags: cmdShift): .redo,
            KeyCombination(keyCode: VirtualKeyCode.a, modifierFlags: cmd): .selectAll,
            KeyCombination(keyCode: VirtualKeyCode.w, modifierFlags: cmd): .closeTab,
            KeyCombination(keyCode: VirtualKeyCode.c, modifierFlags: cmd): .copy,
            KeyCombination(keyCode: VirtualKeyCode.x, modifierFlags: cmd): .cut,
            KeyCombination(keyCode: VirtualKeyCode.v, modifierFlags: cmd): .paste,
            KeyCombination(keyCode: VirtualKeyCode.tab): .togglePaneFocus,
            KeyCombination(keyCode: VirtualKeyCode.help): .toggleInsertMode,
            KeyCombination(keyCode: VirtualKeyCode.pageUp): .pageUp,
            KeyCombination(keyCode: VirtualKeyCode.pageDown): .pageDown,
            KeyCombination(keyCode: VirtualKeyCode.home): .home,
            KeyCombination(keyCode: VirtualKeyCode.end): .end,
            KeyCombination(keyCode: VirtualKeyCode.home, modifierFlags: cmd): .documentStart,
            KeyCombination(keyCode: VirtualKeyCode.end, modifierFlags: cmd): .documentEnd,
        ]

        // Ctrl+Shift+N to set bookmark N, Ctrl+N to jump to bookmark N
        for i in 0..<10 {
            map[KeyCombination(keyCode: numKeys[i], modifierFlags: ctrlShift)] = setActions[i]
            map[KeyCombination(keyCode: numKeys[i], modifierFlags: ctrl)] = goActions[i]
        }

        return map
    }

    /// Looks up the action for a given key event.
    ///
    /// - Parameter event: The key event from AppKit.
    /// - Returns: The matched action, or `nil` if no binding exists.
    public static func action(for event: NSEvent) -> KeyAction? {
        let combination = KeyCombination(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        )
        return bindings[combination]
    }

    /// Resets all bindings to their defaults.
    public static func resetToDefaults() {
        bindings = defaultBindings()
    }

    /// Rebinds an action to a new key combination.
    ///
    /// - Parameters:
    ///   - action: The action to rebind.
    ///   - combination: The new key combination.
    public static func rebind(action: KeyAction, to combination: KeyCombination) {
        bindings = bindings.filter { $0.value != action }
        bindings[combination] = action
    }
}
