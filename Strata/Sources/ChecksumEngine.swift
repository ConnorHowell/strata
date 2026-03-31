// ChecksumEngine.swift
// Strata - macOS Hex Editor

import CryptoKit
import Foundation

// MARK: - ChecksumType

/// Supported checksum and hash algorithms.
public enum ChecksumType: String, CaseIterable {
    /// Simple 8-bit checksum (sum of all bytes mod 256).
    case checksum8 = "Checksum-8"
    /// Simple 16-bit checksum (sum of all bytes mod 65536).
    case checksum16 = "Checksum-16"
    /// Simple 32-bit checksum (sum of all bytes mod 2^32).
    case checksum32 = "Checksum-32"
    /// CRC-16/ARC (polynomial 0x8005).
    case crc16 = "CRC-16"
    /// CRC-32 (polynomial 0xEDB88320, reflected).
    case crc32 = "CRC-32"
    /// CRC-32C (Castagnoli, polynomial 0x82F63B78).
    case crc32c = "CRC-32C"
    /// MD5 message digest.
    case md5 = "MD5"
    /// SHA-1 secure hash.
    case sha1 = "SHA-1"
    /// SHA-256 secure hash.
    case sha256 = "SHA-256"
    /// SHA-384 secure hash.
    case sha384 = "SHA-384"
    /// SHA-512 secure hash.
    case sha512 = "SHA-512"
}

// MARK: - CRCTables

/// Precomputed CRC lookup tables for performance.
private enum CRCTables {

    static let crc16Table: [UInt16] = {
        (0..<256).map { i -> UInt16 in
            var crc = UInt16(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()

    static let crc32Table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB8_8320
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()

    static let crc32cTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0x82F6_3B78
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()
}

// MARK: - ChecksumEngine

/// Computes various checksums and cryptographic hashes for binary data.
public enum ChecksumEngine {

    // MARK: - Public API

    /// Computes the specified checksum for the given data.
    ///
    /// - Parameters:
    ///   - type: The checksum algorithm to use.
    ///   - data: The input data.
    /// - Returns: A lowercase hex string representing the checksum.
    public static func compute(_ type: ChecksumType, data: Data) -> String {
        switch type {
        case .checksum8:
            return computeChecksum8(data)
        case .checksum16:
            return computeChecksum16(data)
        case .checksum32:
            return computeChecksum32(data)
        case .crc16:
            return computeCRC16(data)
        case .crc32:
            return computeCRC32(data)
        case .crc32c:
            return computeCRC32C(data)
        case .md5:
            return computeMD5(data)
        case .sha1:
            return computeSHA1(data)
        case .sha256:
            return computeSHA256(data)
        case .sha384:
            return computeSHA384(data)
        case .sha512:
            return computeSHA512(data)
        }
    }

    /// Computes all supported checksums for the given data.
    ///
    /// - Parameter data: The input data.
    /// - Returns: A dictionary mapping each checksum type to its hex string result.
    public static func computeAll(data: Data) -> [ChecksumType: String] {
        var results: [ChecksumType: String] = [:]
        for type in ChecksumType.allCases {
            results[type] = compute(type, data: data)
        }
        return results
    }

    // MARK: - Private

    private static func computeChecksum8(_ data: Data) -> String {
        var sum: UInt8 = 0
        for byte in data { sum &+= byte }
        return String(format: "%02x", sum)
    }

    private static func computeChecksum16(_ data: Data) -> String {
        var sum: UInt16 = 0
        for byte in data { sum &+= UInt16(byte) }
        return String(format: "%04x", sum)
    }

    private static func computeChecksum32(_ data: Data) -> String {
        var sum: UInt32 = 0
        for byte in data { sum &+= UInt32(byte) }
        return String(format: "%08x", sum)
    }

    private static func computeCRC16(_ data: Data) -> String {
        var crc: UInt16 = 0x0000
        for byte in data {
            let index = Int((crc ^ UInt16(byte)) & 0xFF)
            crc = (crc >> 8) ^ CRCTables.crc16Table[index]
        }
        return String(format: "%04x", crc)
    }

    private static func computeCRC32(_ data: Data) -> String {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ CRCTables.crc32Table[index]
        }
        crc ^= 0xFFFF_FFFF
        return String(format: "%08x", crc)
    }

    private static func computeCRC32C(_ data: Data) -> String {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ CRCTables.crc32cTable[index]
        }
        crc ^= 0xFFFF_FFFF
        return String(format: "%08x", crc)
    }

    private static func computeMD5(_ data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func computeSHA1(_ data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func computeSHA256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func computeSHA384(_ data: Data) -> String {
        let digest = SHA384.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func computeSHA512(_ data: Data) -> String {
        let digest = SHA512.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
