// FileSession.swift
// Strata - macOS Hex Editor

import AppKit
import Foundation

// MARK: - FileSession

/// Represents a single open file editing session with its own piece table and undo stack.
public final class FileSession {

    // MARK: - Public API

    /// The URL of the file on disk, `nil` for untitled documents.
    public private(set) var fileURL: URL?

    /// The piece table backing all edits for this session.
    public let pieceTable: PieceTable

    /// The undo manager for this session.
    public let undoManager: UndoManager

    /// Whether the session has unsaved modifications.
    public var isModified: Bool {
        pieceTable.isDirty
    }

    /// A display name suitable for a tab title.
    public var fileName: String {
        guard let url = fileURL else { return "Untitled" }
        return url.lastPathComponent
    }

    /// Creates a new empty session.
    public init() {
        self.undoManager = UndoManager()
        self.pieceTable = PieceTable(data: Data(), undoManager: undoManager)
        self.fileURL = nil
    }

    /// Opens a file at the given URL using memory-mapped I/O.
    ///
    /// For directory bundles (e.g. `.app`), the URL is resolved to the
    /// bundle's main executable so the raw binary can be edited.
    ///
    /// - Parameter url: The file URL to open.
    /// - Throws: An error if the file cannot be read.
    public init(url: URL) throws {
        self.undoManager = UndoManager()
        let resolvedURL = try Self.resolveURL(url)
        let data = try Data(contentsOf: resolvedURL, options: .mappedIfSafe)
        self.pieceTable = PieceTable(data: data, undoManager: undoManager)
        self.fileURL = resolvedURL
    }

    /// Resolves a URL, handling directory bundles by finding the main executable.
    private static func resolveURL(_ url: URL) throws -> URL {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: url.path, isDirectory: &isDir
        ) else {
            throw FileSessionError.fileNotFound(url.lastPathComponent)
        }
        guard isDir.boolValue else { return url }

        // Try to find the main executable inside a bundle
        if let bundle = Bundle(url: url),
           let execURL = bundle.executableURL {
            return execURL
        }
        throw FileSessionError.isDirectory(url.lastPathComponent)
    }

    /// Saves the current content to the existing file URL.
    ///
    /// - Throws: An error if saving fails or no file URL is set.
    public func save() throws {
        guard let url = fileURL else {
            throw FileSessionError.noFileURL
        }
        try pieceTable.save(to: url)
    }

    /// Saves the current content to a new URL.
    ///
    /// - Parameter url: The destination URL.
    /// - Throws: An error if saving fails.
    public func save(to url: URL) throws {
        try pieceTable.save(to: url)
        fileURL = url
    }

    /// Cleans up resources when the session is closed.
    public func close() {
        undoManager.removeAllActions()
    }
}

// MARK: - FileSessionError

/// Errors specific to file session operations.
public enum FileSessionError: Error, LocalizedError {
    /// No file URL is associated with the session.
    case noFileURL
    /// The path is a directory without a recognizable executable.
    case isDirectory(String)
    /// The file was not found.
    case fileNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .noFileURL:
            return "No file URL is set. Use Save As to specify a location."
        case .isDirectory(let name):
            return "\"\(name)\" is a directory and cannot be opened directly."
        case .fileNotFound(let name):
            return "The file \"\(name)\" was not found."
        }
    }
}

// MARK: - SessionManagerDelegate

/// Delegate protocol for observing changes to the session manager.
public protocol SessionManagerDelegate: AnyObject {
    /// Called when the active session changes.
    func sessionManagerDidChangeActive(_ manager: SessionManager)
    /// Called when a new session is added.
    func sessionManagerDidAddSession(_ manager: SessionManager, at index: Int)
    /// Called when a session is removed.
    func sessionManagerDidRemoveSession(_ manager: SessionManager, at index: Int)
}

// MARK: - SessionManager

/// Manages multiple open file sessions (tabs).
public final class SessionManager {

    // MARK: - Public API

    /// The delegate for session change notifications.
    public weak var delegate: SessionManagerDelegate?

    /// All currently open sessions.
    public private(set) var sessions: [FileSession] = []

    /// The index of the currently active session.
    public private(set) var activeSessionIndex: Int = 0

    /// The currently active session, or `nil` if none are open.
    public var activeSession: FileSession? {
        guard !sessions.isEmpty, activeSessionIndex < sessions.count else { return nil }
        return sessions[activeSessionIndex]
    }

    /// Creates a session manager with no initial sessions.
    public init() {}

    /// Opens a file and creates a new session for it.
    ///
    /// - Parameter url: The file URL to open.
    /// - Returns: The newly created session.
    @discardableResult
    public func openFile(at url: URL) throws -> FileSession {
        let session = try FileSession(url: url)
        sessions.append(session)
        let index = sessions.count - 1
        delegate?.sessionManagerDidAddSession(self, at: index)
        setActive(index: index)
        return session
    }

    /// Creates a new untitled session.
    ///
    /// - Returns: The newly created session.
    @discardableResult
    public func newSession() -> FileSession {
        let session = FileSession()
        sessions.append(session)
        let index = sessions.count - 1
        delegate?.sessionManagerDidAddSession(self, at: index)
        setActive(index: index)
        return session
    }

    /// Closes the session at the given index.
    ///
    /// - Parameter index: The index of the session to close.
    public func closeSession(at index: Int) {
        guard index >= 0, index < sessions.count else { return }
        sessions[index].close()
        sessions.remove(at: index)
        delegate?.sessionManagerDidRemoveSession(self, at: index)
        if sessions.isEmpty {
            activeSessionIndex = 0
            delegate?.sessionManagerDidChangeActive(self)
        } else if activeSessionIndex >= sessions.count {
            setActive(index: sessions.count - 1)
        } else {
            delegate?.sessionManagerDidChangeActive(self)
        }
    }

    /// Sets the active session by index.
    ///
    /// - Parameter index: The index of the session to activate.
    public func setActive(index: Int) {
        guard index >= 0, index < sessions.count else { return }
        activeSessionIndex = index
        delegate?.sessionManagerDidChangeActive(self)
    }
}
