// StringsEngine.swift
// Strata - macOS Hex Editor

import Foundation

// MARK: - StringMatchEncoding

/// Encoding types for string detection.
public enum StringMatchEncoding: String, CaseIterable {
    /// Standard ASCII (printable bytes 0x20–0x7E).
    case ascii = "ASCII"
    /// UTF-16 Little Endian.
    case utf16LE = "UTF-16 LE"
    /// UTF-16 Big Endian.
    case utf16BE = "UTF-16 BE"
}

// MARK: - StringMatch

/// A string found in binary data.
public struct StringMatch {

    /// The byte offset where the string begins.
    public let offset: Int

    /// The decoded string value.
    public let value: String

    /// The encoding used to decode the string.
    public let encoding: StringMatchEncoding

    /// The byte length of the string in the original data.
    public let byteLength: Int
}

// MARK: - StringsEngine

/// Scans binary data for printable strings using memory-mapped I/O
/// and pointer-based scanning for minimal memory footprint.
public enum StringsEngine {

    // MARK: - Public API

    /// Scans a file on disk for printable strings.
    ///
    /// The file is memory-mapped so the kernel manages paging — only
    /// accessed pages are loaded into RAM. Scanning uses direct pointer
    /// access for minimal allocations.
    ///
    /// - Parameters:
    ///   - fileURL: Path to the file on disk.
    ///   - minLength: Minimum character length for a string to be reported.
    ///   - encodings: Which encodings to scan for.
    /// - Returns: An array of string matches sorted by offset.
    public static func scanFile(
        url fileURL: URL,
        minLength: Int = 4,
        encodings: Set<StringMatchEncoding> = [.ascii]
    ) -> [StringMatch] {
        guard let data = try? Data(
            contentsOf: fileURL, options: .mappedIfSafe
        ) else {
            return []
        }
        return scan(
            data: data, minLength: minLength, encodings: encodings
        )
    }

    /// Scans in-memory data for printable strings.
    ///
    /// Uses `withUnsafeBytes` and direct pointer access for efficient
    /// scanning with minimal temporary allocations.
    ///
    /// - Parameters:
    ///   - data: The binary data to scan.
    ///   - minLength: Minimum character length for a string to be reported.
    ///   - encodings: Which encodings to scan for.
    /// - Returns: An array of string matches sorted by offset.
    public static func scan(
        data: Data,
        minLength: Int = 4,
        encodings: Set<StringMatchEncoding> = [.ascii]
    ) -> [StringMatch] {
        var results: [StringMatch] = []
        if encodings.contains(.ascii) {
            results.append(
                contentsOf: scanASCII(data: data, minLength: minLength)
            )
        }
        if encodings.contains(.utf16LE) {
            results.append(
                contentsOf: scanUTF16(
                    data: data, minLength: minLength, bigEndian: false
                )
            )
        }
        if encodings.contains(.utf16BE) {
            results.append(
                contentsOf: scanUTF16(
                    data: data, minLength: minLength, bigEndian: true
                )
            )
        }
        return results.sorted { $0.offset < $1.offset }
    }

    // MARK: - Private – ASCII

    private static func scanASCII(
        data: Data, minLength: Int
    ) -> [StringMatch] {
        var matches: [StringMatch] = []
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?
                .assumingMemoryBound(to: UInt8.self) else { return }
            let count = rawBuffer.count
            var runStart = -1
            var runLen = 0

            for i in 0..<count {
                if isPrintableASCII(base[i]) {
                    if runStart < 0 { runStart = i }
                    runLen += 1
                } else {
                    if runLen >= minLength, runStart >= 0 {
                        let str = String(
                            bytes: UnsafeBufferPointer(
                                start: base + runStart, count: runLen
                            ),
                            encoding: .ascii
                        ) ?? ""
                        matches.append(StringMatch(
                            offset: runStart,
                            value: str,
                            encoding: .ascii,
                            byteLength: runLen
                        ))
                    }
                    runStart = -1
                    runLen = 0
                }
            }
            if runLen >= minLength, runStart >= 0 {
                let str = String(
                    bytes: UnsafeBufferPointer(
                        start: base + runStart, count: runLen
                    ),
                    encoding: .ascii
                ) ?? ""
                matches.append(StringMatch(
                    offset: runStart,
                    value: str,
                    encoding: .ascii,
                    byteLength: runLen
                ))
            }
        }
        return matches
    }

    // MARK: - Private – UTF-16

    private static func scanUTF16(
        data: Data, minLength: Int, bigEndian: Bool
    ) -> [StringMatch] {
        var matches: [StringMatch] = []
        guard data.count >= 2 else { return matches }

        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?
                .assumingMemoryBound(to: UInt8.self) else { return }
            let count = rawBuffer.count
            var runStart = -1
            var runLen = 0
            var i = 0

            while i + 1 < count {
                let codeUnit: UInt16
                if bigEndian {
                    codeUnit = UInt16(base[i]) << 8 | UInt16(base[i + 1])
                } else {
                    codeUnit = UInt16(base[i + 1]) << 8 | UInt16(base[i])
                }

                if isPrintableUnicode(codeUnit) {
                    if runStart < 0 { runStart = i }
                    runLen += 1
                } else {
                    if runLen >= minLength, runStart >= 0 {
                        let byteLen = runLen * 2
                        let str = decodeUTF16Run(
                            base: base, start: runStart,
                            charCount: runLen, bigEndian: bigEndian
                        )
                        matches.append(StringMatch(
                            offset: runStart,
                            value: str,
                            encoding: bigEndian ? .utf16BE : .utf16LE,
                            byteLength: byteLen
                        ))
                    }
                    runStart = -1
                    runLen = 0
                }
                i += 2
            }
            if runLen >= minLength, runStart >= 0 {
                let byteLen = runLen * 2
                let str = decodeUTF16Run(
                    base: base, start: runStart,
                    charCount: runLen, bigEndian: bigEndian
                )
                matches.append(StringMatch(
                    offset: runStart,
                    value: str,
                    encoding: bigEndian ? .utf16BE : .utf16LE,
                    byteLength: byteLen
                ))
            }
        }
        return matches
    }

    private static func decodeUTF16Run(
        base: UnsafePointer<UInt8>,
        start: Int, charCount: Int, bigEndian: Bool
    ) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(charCount)
        for j in 0..<charCount {
            let off = start + j * 2
            let cu: UInt16
            if bigEndian {
                cu = UInt16(base[off]) << 8 | UInt16(base[off + 1])
            } else {
                cu = UInt16(base[off + 1]) << 8 | UInt16(base[off])
            }
            if let scalar = Unicode.Scalar(cu) {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    // MARK: - Private – Character classification

    private static func isPrintableASCII(_ byte: UInt8) -> Bool {
        byte >= 0x20 && byte <= 0x7E
    }

    private static func isPrintableUnicode(_ codeUnit: UInt16) -> Bool {
        (codeUnit >= 0x0020 && codeUnit <= 0x007E)
            || (codeUnit >= 0x00A0 && codeUnit <= 0xD7FF)
    }
}
