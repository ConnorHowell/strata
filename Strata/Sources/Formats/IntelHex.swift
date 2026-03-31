// IntelHex.swift
// Strata - macOS Hex Editor

import Foundation

// MARK: - IntelHexError

/// Errors encountered when parsing Intel HEX files.
public enum IntelHexError: Error, LocalizedError {
    /// A line is missing the required colon prefix.
    case missingStartCode(line: Int)
    /// A line has an invalid or truncated format.
    case malformedLine(line: Int)
    /// The checksum did not match the computed value.
    case badChecksum(line: Int, expected: UInt8, actual: UInt8)
    /// An unsupported record type was encountered.
    case invalidRecordType(line: Int, type: UInt8)

    public var errorDescription: String? {
        switch self {
        case .missingStartCode(let line):
            return "Line \(line): missing ':' start code."
        case .malformedLine(let line):
            return "Line \(line): malformed record."
        case .badChecksum(let line, let expected, let actual):
            return "Line \(line): bad checksum (expected \(expected), got \(actual))."
        case .invalidRecordType(let line, let type):
            return "Line \(line): unsupported record type 0x\(String(format: "%02X", type))."
        }
    }
}

// MARK: - IntelHex

/// Parser and encoder for the Intel HEX file format.
public enum IntelHex {

    // MARK: - RecordType

    /// Intel HEX record types.
    public enum RecordType: UInt8 {
        /// Data record.
        case data = 0x00
        /// End-of-file record.
        case eof = 0x01
        /// Extended segment address record.
        case extendedSegmentAddress = 0x02
        /// Start segment address record.
        case startSegmentAddress = 0x03
        /// Extended linear address record.
        case extendedLinearAddress = 0x04
        /// Start linear address record.
        case startLinearAddress = 0x05
    }

    // MARK: - Record

    /// A single Intel HEX record.
    public struct Record: Equatable {
        /// The record type.
        public let type: RecordType
        /// The address field.
        public let address: UInt16
        /// The data payload.
        public let data: Data
    }

    // MARK: - Public API

    /// Parses an Intel HEX string into records.
    ///
    /// - Parameter string: The Intel HEX content.
    /// - Returns: An array of parsed records.
    /// - Throws: `IntelHexError` on malformed input.
    public static func parse(_ string: String) throws -> [Record] {
        let lines = string.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var records: [Record] = []

        for (lineNum, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(":") else {
                throw IntelHexError.missingStartCode(line: lineNum + 1)
            }

            let hex = String(trimmed.dropFirst())
            guard hex.count >= 10, hex.count % 2 == 0 else {
                throw IntelHexError.malformedLine(line: lineNum + 1)
            }

            let rawBytes = try parseHexBytes(hex, line: lineNum + 1)
            guard rawBytes.count >= 5 else {
                throw IntelHexError.malformedLine(line: lineNum + 1)
            }

            let byteCount = rawBytes[0]
            let address = UInt16(rawBytes[1]) << 8 | UInt16(rawBytes[2])
            let typeRaw = rawBytes[3]
            let checksum = rawBytes[rawBytes.count - 1]

            guard rawBytes.count == Int(byteCount) + 5 else {
                throw IntelHexError.malformedLine(line: lineNum + 1)
            }

            guard let recordType = RecordType(rawValue: typeRaw) else {
                throw IntelHexError.invalidRecordType(line: lineNum + 1, type: typeRaw)
            }

            let computed = computeChecksum(Array(rawBytes.dropLast()))
            guard checksum == computed else {
                throw IntelHexError.badChecksum(
                    line: lineNum + 1,
                    expected: computed,
                    actual: checksum
                )
            }

            let payload = Data(rawBytes[4..<(rawBytes.count - 1)])
            records.append(Record(type: recordType, address: address, data: payload))
        }

        return records
    }

    /// Converts parsed records into flat binary data, resolving addresses.
    ///
    /// - Parameter records: The parsed Intel HEX records.
    /// - Returns: The reconstructed binary data.
    public static func toData(_ records: [Record]) -> Data {
        var baseAddress: UInt32 = 0
        var segments: [(address: UInt32, data: Data)] = []

        for record in records {
            switch record.type {
            case .extendedLinearAddress:
                guard record.data.count >= 2 else { continue }
                baseAddress = UInt32(record.data[0]) << 24 | UInt32(record.data[1]) << 16
            case .extendedSegmentAddress:
                guard record.data.count >= 2 else { continue }
                baseAddress = (UInt32(record.data[0]) << 8 | UInt32(record.data[1])) << 4
            case .data:
                let addr = baseAddress + UInt32(record.address)
                segments.append((address: addr, data: record.data))
            case .eof, .startSegmentAddress, .startLinearAddress:
                break
            }
        }

        guard let minAddr = segments.map({ $0.address }).min() else { return Data() }
        let maxEnd = segments.map { $0.address + UInt32($0.data.count) }.max() ?? minAddr
        let size = Int(maxEnd - minAddr)
        var result = Data(count: size)
        for segment in segments {
            let offset = Int(segment.address - minAddr)
            result.replaceSubrange(offset..<(offset + segment.data.count), with: segment.data)
        }
        return result
    }

    /// Encodes binary data as an Intel HEX string.
    ///
    /// - Parameters:
    ///   - data: The binary data to encode.
    ///   - startAddress: The starting address (default 0).
    /// - Returns: The Intel HEX formatted string.
    public static func fromData(_ data: Data, startAddress: UInt32 = 0) -> String {
        var lines: [String] = []
        let bytesPerLine = 16
        var offset = 0
        var currentExtAddr: UInt16 = UInt16((startAddress >> 16) & 0xFFFF)

        if currentExtAddr != 0 {
            lines.append(formatRecord(
                type: .extendedLinearAddress,
                address: 0,
                data: Data([UInt8(currentExtAddr >> 8), UInt8(currentExtAddr & 0xFF)])
            ))
        }

        while offset < data.count {
            let fullAddr = startAddress + UInt32(offset)
            let extAddr = UInt16((fullAddr >> 16) & 0xFFFF)
            if extAddr != currentExtAddr {
                currentExtAddr = extAddr
                lines.append(formatRecord(
                    type: .extendedLinearAddress,
                    address: 0,
                    data: Data([UInt8(extAddr >> 8), UInt8(extAddr & 0xFF)])
                ))
            }
            let lineAddr = UInt16(fullAddr & 0xFFFF)
            let count = min(bytesPerLine, data.count - offset)
            let chunk = data[offset..<(offset + count)]
            lines.append(formatRecord(type: .data, address: lineAddr, data: Data(chunk)))
            offset += count
        }

        lines.append(formatRecord(type: .eof, address: 0, data: Data()))
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private static func parseHexBytes(_ hex: String, line: Int) throws -> [UInt8] {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex)
            guard let end = nextIndex else {
                throw IntelHexError.malformedLine(line: line)
            }
            let byteStr = String(hex[index..<end])
            guard let byte = UInt8(byteStr, radix: 16) else {
                throw IntelHexError.malformedLine(line: line)
            }
            bytes.append(byte)
            index = end
        }
        return bytes
    }

    private static func computeChecksum(_ bytes: [UInt8]) -> UInt8 {
        let sum = bytes.reduce(0) { (acc: UInt16, val: UInt8) in acc &+ UInt16(val) }
        return UInt8((~sum &+ 1) & 0xFF)
    }

    private static func formatRecord(type: RecordType, address: UInt16, data: Data) -> String {
        var bytes: [UInt8] = []
        bytes.append(UInt8(data.count))
        bytes.append(UInt8(address >> 8))
        bytes.append(UInt8(address & 0xFF))
        bytes.append(type.rawValue)
        bytes.append(contentsOf: data)
        let checksum = computeChecksum(bytes)
        bytes.append(checksum)
        return ":" + bytes.map { String(format: "%02X", $0) }.joined()
    }
}
