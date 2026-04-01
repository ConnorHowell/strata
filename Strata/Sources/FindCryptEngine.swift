// FindCryptEngine.swift
// Strata - macOS Hex Editor

import Foundation

// MARK: - CryptoSignature

/// A known cryptographic constant signature for detection.
public struct CryptoSignature: Codable {

    /// Human-readable name (e.g. "AES S-box").
    public let name: String

    /// Category (e.g. "AES", "SHA", "DES").
    public let category: String

    /// Hex-encoded byte sequence.
    public let hexBytes: String

    /// Size of each element in bytes for endian swapping (1 = byte-oriented, 4 = 32-bit).
    public let elementSize: Int
}

// MARK: - FindCryptMatch

/// A detected cryptographic constant in the scanned data.
public struct FindCryptMatch {

    /// Byte offset where the match begins.
    public let offset: Int

    /// Name of the matched signature.
    public let signatureName: String

    /// Category of the matched algorithm.
    public let category: String

    /// Detected endianness: "native", "swapped", or "N/A".
    public let endianness: String

    /// Confidence level: 1.0 for exact match, lower for partial.
    public let confidence: Double
}

// MARK: - FindCryptEngine

/// Scans binary data for known cryptographic constants.
public enum FindCryptEngine {

    // MARK: - Public API

    /// Loads crypto signatures from a JSON file.
    ///
    /// - Parameter url: The URL of the JSON signatures file.
    /// - Returns: An array of crypto signatures, or empty if loading fails.
    public static func loadSignatures(from url: URL) -> [CryptoSignature] {
        guard let jsonData = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([CryptoSignature].self, from: jsonData)) ?? []
    }

    /// Scans data for known cryptographic constants.
    ///
    /// - Parameters:
    ///   - data: The binary data to scan.
    ///   - signatures: The signature database to search for.
    ///   - partialThreshold: Minimum fraction for partial match (default 0.8).
    /// - Returns: An array of matches sorted by offset.
    public static func scan(
        data: Data,
        signatures: [CryptoSignature],
        partialThreshold: Double = 0.8
    ) -> [FindCryptMatch] {
        var matches: [FindCryptMatch] = []
        for sig in signatures {
            guard let sigBytes = hexToBytes(sig.hexBytes) else { continue }
            guard sigBytes.count >= 4 else { continue }
            let sigData = Data(sigBytes)

            let elemSize = sig.elementSize
            let cat = sig.category

            // Stage 1: exact match (native byte order)
            if let offset = findExact(in: data, pattern: sigData) {
                matches.append(FindCryptMatch(
                    offset: offset,
                    signatureName: sig.name,
                    category: cat,
                    endianness: "native",
                    confidence: 1.0
                ))
                continue
            }

            // Try byte-swapped version if element size > 1
            if elemSize > 1 {
                let swapped = byteSwap(sigBytes, elementSize: elemSize)
                let swappedData = Data(swapped)
                if let offset = findExact(in: data, pattern: swappedData) {
                    matches.append(FindCryptMatch(
                        offset: offset,
                        signatureName: sig.name,
                        category: cat,
                        endianness: "swapped",
                        confidence: 1.0
                    ))
                    continue
                }
            }

            // Stage 2: partial match
            if let match = findPartial(
                in: data,
                sigBytes: sigBytes,
                elementSize: elemSize,
                threshold: partialThreshold,
                signature: sig
            ) {
                matches.append(match)
            }
        }
        return matches.sorted { $0.offset < $1.offset }
    }

    /// Converts a hex string to bytes.
    ///
    /// - Parameter hex: A hex string (even length, no separators).
    /// - Returns: The decoded bytes, or nil if the string is invalid.
    public static func hexToBytes(_ hex: String) -> [UInt8]? {
        let chars = Array(hex)
        guard chars.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = hexVal(chars[i]),
                  let lo = hexVal(chars[i + 1]) else { return nil }
            bytes.append(hi << 4 | lo)
            i += 2
        }
        return bytes
    }

    // MARK: - Private

    private static func hexVal(_ c: Character) -> UInt8? {
        guard let ascii = c.asciiValue else { return nil }
        switch c {
        case "0"..."9": return ascii - 0x30
        case "a"..."f": return ascii - 0x61 + 10
        case "A"..."F": return ascii - 0x41 + 10
        default: return nil
        }
    }

    private static func findExact(in data: Data, pattern: Data) -> Int? {
        guard pattern.count <= data.count else { return nil }
        if let range = data.range(of: pattern) {
            return range.lowerBound
        }
        return nil
    }

    private static func byteSwap(_ bytes: [UInt8], elementSize: Int) -> [UInt8] {
        guard elementSize > 1 else { return bytes }
        var result = bytes
        let count = bytes.count / elementSize
        for i in 0..<count {
            let start = i * elementSize
            let end = start + elementSize
            let slice = Array(bytes[start..<end])
            for j in 0..<elementSize {
                result[start + j] = slice[elementSize - 1 - j]
            }
        }
        return result
    }

    private static func findPartial(
        in data: Data,
        sigBytes: [UInt8],
        elementSize: Int,
        threshold: Double,
        signature: CryptoSignature
    ) -> FindCryptMatch? {
        let blockSize = max(elementSize, 4)
        guard sigBytes.count >= blockSize else { return nil }

        let totalBlocks = sigBytes.count / blockSize
        guard totalBlocks >= 2 else { return nil }
        let blocksToCheck = min(totalBlocks, 20)

        let ctx = PartialContext(
            blockSize: blockSize, blocksToCheck: blocksToCheck,
            threshold: threshold, signature: signature
        )

        // Check native byte order
        if let match = checkPartialOrder(in: data, sigBytes: sigBytes,
                                          ctx: ctx, endianness: "native") {
            return match
        }

        // Check swapped byte order
        if elementSize > 1 {
            let swapped = byteSwap(sigBytes, elementSize: elementSize)
            if let match = checkPartialOrder(in: data, sigBytes: swapped,
                                              ctx: ctx, endianness: "swapped") {
                return match
            }
        }

        return nil
    }

    private struct PartialContext {
        let blockSize: Int
        let blocksToCheck: Int
        let threshold: Double
        let signature: CryptoSignature
    }

    private static func checkPartialOrder(
        in data: Data,
        sigBytes: [UInt8],
        ctx: PartialContext,
        endianness: String
    ) -> FindCryptMatch? {
        let bs = ctx.blockSize
        // Find where first block appears
        let firstBlock = Data(sigBytes[0..<bs])
        guard let baseOffset = findExact(in: data, pattern: firstBlock) else {
            return nil
        }

        // Check how many subsequent blocks appear near expected positions
        var found = 1
        for b in 1..<ctx.blocksToCheck {
            let blockStart = b * bs
            let blockEnd = blockStart + bs
            guard blockEnd <= sigBytes.count else { break }
            let block = Data(sigBytes[blockStart..<blockEnd])
            let expectedOffset = baseOffset + blockStart
            let searchStart = max(0, expectedOffset - bs)
            let searchEnd = min(data.count, expectedOffset + bs * 2)
            guard searchStart < searchEnd else { continue }
            let searchRange = data[searchStart..<searchEnd]
            if searchRange.range(of: block) != nil {
                found += 1
            }
        }

        let confidence = Double(found) / Double(ctx.blocksToCheck)
        if confidence >= ctx.threshold {
            return FindCryptMatch(
                offset: baseOffset,
                signatureName: ctx.signature.name,
                category: ctx.signature.category,
                endianness: endianness,
                confidence: confidence
            )
        }
        return nil
    }
}
