// SearchEngine.swift
// Strata - macOS Hex Editor

import Foundation

// MARK: - SearchEngine

/// Stateless byte-level search utilities for PieceTable data sources.
public enum SearchEngine {

    // MARK: - Public API

    /// Lowercases an ASCII uppercase byte. Non-alpha bytes pass through unchanged.
    public static func toLower(_ byte: UInt8) -> UInt8 {
        (byte >= 0x41 && byte <= 0x5A) ? byte + 0x20 : byte
    }

    /// Wrapping search that scans the full data source starting from `start`.
    ///
    /// Supports forward, backward, and all directions. Wraps around the
    /// end/start of the data so the entire file is always searched.
    public static func wrappingSearch(
        in ds: PieceTable, length len: Int,
        pattern: SearchPattern, from start: Int
    ) -> Int? {
        let patLen = pattern.data.count
        guard patLen > 0, patLen <= len else { return nil }
        let caseInsensitive = !pattern.caseSensitive
        for i in 0..<len {
            let pos: Int
            switch pattern.direction {
            case .backward:
                pos = ((start - i) % len + len) % len
            default:
                pos = (start + i) % len
            }
            guard pos + patLen <= len else { continue }
            if matchAt(
                ds: ds, pos: pos, pattern: pattern,
                caseInsensitive: caseInsensitive
            ) {
                return pos
            }
        }
        return nil
    }

    /// Linear forward-only scan for a match at or after `start`. No wrapping.
    public static func linearSearch(
        in ds: PieceTable, length len: Int,
        pattern: SearchPattern, from start: Int
    ) -> Int? {
        let patLen = pattern.data.count
        guard patLen > 0, start >= 0, start + patLen <= len else { return nil }
        let caseInsensitive = !pattern.caseSensitive
        var pos = start
        while pos + patLen <= len {
            if matchAt(
                ds: ds, pos: pos, pattern: pattern,
                caseInsensitive: caseInsensitive
            ) {
                return pos
            }
            pos += 1
        }
        return nil
    }

    /// Counts total matches for a pattern. Stops at `maxCount` to avoid hangs.
    public static func countMatches(
        in ds: PieceTable, length len: Int,
        pattern: SearchPattern, maxCount: Int = 10_000
    ) -> Int {
        let patLen = pattern.data.count
        guard patLen > 0, patLen <= len else { return 0 }
        var count = 0
        var offset = 0
        while offset <= len - patLen, count < maxCount {
            guard let found = linearSearch(
                in: ds, length: len, pattern: pattern, from: offset
            ) else { break }
            count += 1
            offset = found + 1
        }
        return count
    }

    /// Returns the 1-based index of the match at `pos` among all matches.
    public static func matchIndex(
        in ds: PieceTable, length len: Int,
        pattern: SearchPattern, at pos: Int
    ) -> Int {
        let patLen = pattern.data.count
        guard patLen > 0, patLen <= len else { return 0 }
        var idx = 0
        var offset = 0
        while offset <= pos {
            guard let found = linearSearch(
                in: ds, length: len, pattern: pattern, from: offset
            ), found <= pos else { break }
            idx += 1
            offset = found + 1
        }
        return idx
    }

    // MARK: - Private

    private static func matchAt(
        ds: PieceTable, pos: Int, pattern: SearchPattern,
        caseInsensitive: Bool
    ) -> Bool {
        let patLen = pattern.data.count
        for j in 0..<patLen {
            guard let byte = ds.byte(at: pos + j) else { return false }
            if let mask = pattern.mask {
                if byte & mask[j] != pattern.data[j] & mask[j] { return false }
            } else if caseInsensitive {
                if toLower(byte) != toLower(pattern.data[j]) { return false }
            } else if byte != pattern.data[j] {
                return false
            }
        }
        return true
    }
}
