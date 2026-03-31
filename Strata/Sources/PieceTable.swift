// PieceTable.swift
// Strata - macOS Hex Editor

import Foundation

// MARK: - PieceSource

/// Indicates whether a piece refers to the original buffer or the add buffer.
public enum PieceSource {
    /// Data from the original (read-only) file buffer.
    case original
    /// Data from the mutable add buffer.
    case add
}

// MARK: - Piece

/// A descriptor pointing to a contiguous range of bytes in one of the two buffers.
public struct Piece: Equatable {
    /// Which buffer this piece references.
    let source: PieceSource
    /// Starting offset within the referenced buffer.
    let offset: Int
    /// Number of bytes.
    let length: Int
}

// MARK: - PieceTable

/// A piece-table data structure supporting non-destructive insert, overwrite, and delete
/// operations with full undo/redo via `UndoManager`.
public final class PieceTable {

    // MARK: - Public API

    /// The undo manager backing all edit operations.
    public let undoManager: UndoManager

    /// The total number of bytes represented by the piece table.
    public var totalLength: Int {
        pieces.reduce(0) { $0 + $1.length }
    }

    /// Whether any edits have been performed since the last save point.
    public private(set) var isDirty: Bool = false

    /// Creates a piece table backed by the given data.
    ///
    /// - Parameters:
    ///   - data: The original file data (ideally memory-mapped).
    ///   - undoManager: An undo manager to register operations with.
    public init(data: Data = Data(), undoManager: UndoManager = UndoManager()) {
        self.originalBuffer = data
        self.addBuffer = Data()
        self.undoManager = undoManager
        if data.isEmpty {
            self.pieces = []
        } else {
            self.pieces = [Piece(source: .original, offset: 0, length: data.count)]
        }
    }

    /// Returns the byte at the given logical offset.
    ///
    /// - Parameter index: The logical byte offset.
    /// - Returns: The byte value, or `nil` if out of range.
    public func byte(at index: Int) -> UInt8? {
        guard index >= 0, index < totalLength else { return nil }
        var remaining = index
        for piece in pieces {
            if remaining < piece.length {
                return bufferByte(piece: piece, offset: remaining)
            }
            remaining -= piece.length
        }
        return nil
    }

    /// Returns whether the byte at the given offset came from the add buffer (was modified).
    ///
    /// - Parameter index: The logical byte offset.
    /// - Returns: `true` if the byte was inserted or overwritten.
    public func isModified(at index: Int) -> Bool {
        guard index >= 0, index < totalLength else { return false }
        var remaining = index
        for piece in pieces {
            if remaining < piece.length {
                return piece.source == .add
            }
            remaining -= piece.length
        }
        return false
    }

    /// Returns a contiguous copy of bytes in the given range.
    ///
    /// - Parameter range: The logical byte range.
    /// - Returns: A `Data` containing the requested bytes.
    public func bytes(in range: Range<Int>) -> Data {
        var result = Data(capacity: range.count)
        for i in range {
            guard let b = byte(at: i) else { break }
            result.append(b)
        }
        return result
    }

    /// Subscript access to individual bytes.
    public subscript(index: Int) -> UInt8? {
        byte(at: index)
    }

    /// Inserts bytes at the given logical offset.
    ///
    /// - Parameters:
    ///   - offset: The insertion point.
    ///   - newBytes: The bytes to insert.
    public func insert(at offset: Int, bytes newBytes: Data) {
        guard !newBytes.isEmpty else { return }
        let clampedOffset = min(max(offset, 0), totalLength)
        let addOffset = addBuffer.count
        addBuffer.append(newBytes)
        let newPiece = Piece(source: .add, offset: addOffset, length: newBytes.count)
        let snapshot = pieces
        insertPiece(newPiece, at: clampedOffset)
        isDirty = true
        registerUndoRestore(snapshot: snapshot, actionName: "Insert \(newBytes.count) byte(s)")
    }

    /// Overwrites bytes starting at the given logical offset.
    ///
    /// - Parameters:
    ///   - offset: The starting offset for overwrite.
    ///   - newBytes: The replacement bytes.
    public func overwrite(at offset: Int, bytes newBytes: Data) {
        guard !newBytes.isEmpty else { return }
        let end = min(offset + newBytes.count, totalLength)
        guard offset >= 0, offset < totalLength else { return }
        let snapshot = pieces
        let addOffset = addBuffer.count
        addBuffer.append(newBytes)
        let overwriteLength = end - offset
        let newPiece = Piece(
            source: .add,
            offset: addOffset,
            length: overwriteLength
        )
        removePieces(in: offset..<end)
        insertPiece(newPiece, at: offset)
        isDirty = true
        registerUndoRestore(snapshot: snapshot, actionName: "Overwrite \(overwriteLength) byte(s)")
    }

    /// Deletes bytes in the given range.
    ///
    /// - Parameter range: The range of bytes to delete.
    public func delete(range: Range<Int>) {
        guard !range.isEmpty else { return }
        let clamped = max(range.lowerBound, 0)..<min(range.upperBound, totalLength)
        guard !clamped.isEmpty else { return }
        let snapshot = pieces
        removePieces(in: clamped)
        isDirty = true
        registerUndoRestore(snapshot: snapshot, actionName: "Delete \(clamped.count) byte(s)")
    }

    /// Writes the current content to a file URL.
    ///
    /// - Parameter url: The destination file URL.
    public func save(to url: URL) throws {
        var output = Data(capacity: totalLength)
        for piece in pieces {
            let buffer = piece.source == .original ? originalBuffer : addBuffer
            let start = piece.offset
            let end = start + piece.length
            output.append(buffer[start..<end])
        }
        try output.write(to: url, options: .atomic)
        isDirty = false
    }

    /// Marks the current state as the save point.
    public func markClean() {
        isDirty = false
    }

    // MARK: - Private

    private let originalBuffer: Data
    private var addBuffer: Data
    private var pieces: [Piece]

    private func registerUndoRestore(snapshot: [Piece], actionName: String) {
        let currentPieces = pieces
        undoManager.registerUndo(withTarget: self) { target in
            target.pieces = snapshot
            target.isDirty = true
            target.undoManager.registerUndo(withTarget: target) { redoTarget in
                redoTarget.pieces = currentPieces
                redoTarget.isDirty = true
            }
            target.undoManager.setActionName(actionName)
        }
        undoManager.setActionName(actionName)
    }

    private func bufferByte(piece: Piece, offset: Int) -> UInt8 {
        let buffer = piece.source == .original ? originalBuffer : addBuffer
        return buffer[piece.offset + offset]
    }

    private func insertPiece(_ newPiece: Piece, at logicalOffset: Int) {
        var remaining = logicalOffset
        for i in 0..<pieces.count {
            let piece = pieces[i]
            if remaining == 0 {
                pieces.insert(newPiece, at: i)
                return
            }
            if remaining < piece.length {
                let left = Piece(
                    source: piece.source,
                    offset: piece.offset,
                    length: remaining
                )
                let right = Piece(
                    source: piece.source,
                    offset: piece.offset + remaining,
                    length: piece.length - remaining
                )
                pieces.replaceSubrange(i...i, with: [left, newPiece, right])
                return
            }
            remaining -= piece.length
        }
        pieces.append(newPiece)
    }

    private func removePieces(in range: Range<Int>) {
        var newPieces: [Piece] = []
        var pos = 0
        for piece in pieces {
            let pieceEnd = pos + piece.length
            if pieceEnd <= range.lowerBound || pos >= range.upperBound {
                newPieces.append(piece)
            } else {
                if pos < range.lowerBound {
                    let keep = range.lowerBound - pos
                    newPieces.append(Piece(
                        source: piece.source,
                        offset: piece.offset,
                        length: keep
                    ))
                }
                if pieceEnd > range.upperBound {
                    let skip = range.upperBound - pos
                    newPieces.append(Piece(
                        source: piece.source,
                        offset: piece.offset + skip,
                        length: piece.length - skip
                    ))
                }
            }
            pos = pieceEnd
        }
        pieces = newPieces
    }
}
