// SRecord.swift
// Strata - macOS Hex Editor

import Foundation

// MARK: - SRecordError

/// Errors encountered when parsing Motorola S-record files.
public enum SRecordError: Error, LocalizedError {
    /// A line is missing the 'S' prefix.
    case missingPrefix(line: Int)
    /// A line has an invalid or truncated format.
    case malformedLine(line: Int)
    /// The checksum did not match.
    case badChecksum(line: Int, expected: UInt8, actual: UInt8)
    /// An unsupported record type was encountered.
    case invalidRecordType(line: Int, type: String)

    public var errorDescription: String? {
        switch self {
        case .missingPrefix(let line):
            return "Line \(line): missing 'S' prefix."
        case .malformedLine(let line):
            return "Line \(line): malformed record."
        case .badChecksum(let line, let expected, let actual):
            return "Line \(line): checksum mismatch (expected \(expected), got \(actual))."
        case .invalidRecordType(let line, let type):
            return "Line \(line): unsupported record type '\(type)'."
        }
    }
}

// MARK: - SRecord

/// Parser and encoder for the Motorola S-record file format.
public enum SRecord {

    // MARK: - RecordType

    /// Motorola S-record types.
    public enum RecordType: String, Equatable {
        /// Header record.
        case s0 = "S0"
        /// Data record with 16-bit address.
        case s1 = "S1"
        /// Data record with 24-bit address.
        case s2 = "S2"
        /// Data record with 32-bit address.
        case s3 = "S3"
        /// Record count.
        case s5 = "S5"
        /// End record for S3 (32-bit start address).
        case s7 = "S7"
        /// End record for S2 (24-bit start address).
        case s8 = "S8"
        /// End record for S1 (16-bit start address).
        case s9 = "S9"
    }

    // MARK: - AddressWidth

    /// The address width used for encoding.
    public enum AddressWidth: Int {
        /// 16-bit addressing (S1/S9).
        case bit16 = 2
        /// 24-bit addressing (S2/S8).
        case bit24 = 3
        /// 32-bit addressing (S3/S7).
        case bit32 = 4
    }

    // MARK: - Record

    /// A single S-record entry.
    public struct Record: Equatable {
        /// The record type.
        public let type: RecordType
        /// The address field.
        public let address: UInt32
        /// The data payload.
        public let data: Data
    }

    // MARK: - Public API

    /// Parses a Motorola S-record string into records.
    ///
    /// - Parameter string: The S-record content.
    /// - Returns: An array of parsed records.
    /// - Throws: `SRecordError` on malformed input.
    public static func parse(_ string: String) throws -> [Record] {
        let lines = string.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var records: [Record] = []

        for (lineNum, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("S") else {
                throw SRecordError.missingPrefix(line: lineNum + 1)
            }
            guard trimmed.count >= 4 else {
                throw SRecordError.malformedLine(line: lineNum + 1)
            }

            let typeStr = String(trimmed.prefix(2))
            guard let recordType = RecordType(rawValue: typeStr) else {
                throw SRecordError.invalidRecordType(line: lineNum + 1, type: typeStr)
            }

            let hex = String(trimmed.dropFirst(2))
            let rawBytes = try parseHexBytes(hex, line: lineNum + 1)
            guard rawBytes.count >= 1 else {
                throw SRecordError.malformedLine(line: lineNum + 1)
            }

            let byteCount = Int(rawBytes[0])
            guard rawBytes.count == byteCount + 1 else {
                throw SRecordError.malformedLine(line: lineNum + 1)
            }

            let checksum = rawBytes[rawBytes.count - 1]
            let computed = computeChecksum(Array(rawBytes.dropLast()))
            guard checksum == computed else {
                throw SRecordError.badChecksum(
                    line: lineNum + 1,
                    expected: computed,
                    actual: checksum
                )
            }

            let addrSize = addressSize(for: recordType)
            guard rawBytes.count >= 1 + addrSize + 1 else {
                throw SRecordError.malformedLine(line: lineNum + 1)
            }

            var address: UInt32 = 0
            for i in 0..<addrSize {
                address = (address << 8) | UInt32(rawBytes[1 + i])
            }

            let dataStart = 1 + addrSize
            let dataEnd = rawBytes.count - 1
            let payload = dataStart < dataEnd ? Data(rawBytes[dataStart..<dataEnd]) : Data()

            records.append(Record(type: recordType, address: address, data: payload))
        }

        return records
    }

    /// Converts parsed S-records into flat binary data.
    ///
    /// - Parameter records: The parsed S-record entries.
    /// - Returns: The reconstructed binary data.
    public static func toData(_ records: [Record]) -> Data {
        let dataRecords = records.filter { [.s1, .s2, .s3].contains($0.type) }
        guard let minAddr = dataRecords.map({ $0.address }).min() else { return Data() }
        let maxEnd = dataRecords.map { $0.address + UInt32($0.data.count) }.max() ?? minAddr
        let size = Int(maxEnd - minAddr)
        var result = Data(count: size)
        for record in dataRecords {
            let offset = Int(record.address - minAddr)
            result.replaceSubrange(offset..<(offset + record.data.count), with: record.data)
        }
        return result
    }

    /// Encodes binary data as a Motorola S-record string.
    ///
    /// - Parameters:
    ///   - data: The binary data to encode.
    ///   - startAddress: The base address (default 0).
    ///   - addressWidth: The address size to use (default 16-bit).
    /// - Returns: The S-record formatted string.
    public static func fromData(
        _ data: Data,
        startAddress: UInt32 = 0,
        addressWidth: AddressWidth = .bit16
    ) -> String {
        var lines: [String] = []
        let bytesPerLine = 16
        let addrSize = addressWidth.rawValue

        let (dataType, endType) = recordTypes(for: addressWidth)

        lines.append(formatRecord(type: .s0, address: 0, data: Data(), addrSize: 2))

        var offset = 0
        var recordCount: UInt16 = 0
        while offset < data.count {
            let addr = startAddress + UInt32(offset)
            let count = min(bytesPerLine, data.count - offset)
            let chunk = data[offset..<(offset + count)]
            lines.append(formatRecord(
                type: dataType,
                address: addr,
                data: Data(chunk),
                addrSize: addrSize
            ))
            offset += count
            recordCount += 1
        }

        lines.append(formatRecord(type: .s5, address: UInt32(recordCount), data: Data(), addrSize: 2))
        lines.append(formatRecord(type: endType, address: startAddress, data: Data(), addrSize: addrSize))

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private static func addressSize(for type: RecordType) -> Int {
        switch type {
        case .s0, .s1, .s5, .s9: return 2
        case .s2, .s8: return 3
        case .s3, .s7: return 4
        }
    }

    private static func recordTypes(for width: AddressWidth) -> (RecordType, RecordType) {
        switch width {
        case .bit16: return (.s1, .s9)
        case .bit24: return (.s2, .s8)
        case .bit32: return (.s3, .s7)
        }
    }

    private static func parseHexBytes(_ hex: String, line: Int) throws -> [UInt8] {
        guard hex.count % 2 == 0 else {
            throw SRecordError.malformedLine(line: line)
        }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            guard let end = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) else {
                throw SRecordError.malformedLine(line: line)
            }
            guard let byte = UInt8(String(hex[index..<end]), radix: 16) else {
                throw SRecordError.malformedLine(line: line)
            }
            bytes.append(byte)
            index = end
        }
        return bytes
    }

    private static func computeChecksum(_ bytes: [UInt8]) -> UInt8 {
        let sum = bytes.reduce(0) { (acc: UInt16, val: UInt8) in acc &+ UInt16(val) }
        return ~UInt8(sum & 0xFF)
    }

    private static func formatRecord(
        type: RecordType,
        address: UInt32,
        data: Data,
        addrSize: Int
    ) -> String {
        var bytes: [UInt8] = []
        bytes.append(UInt8(addrSize + data.count + 1))
        for i in stride(from: addrSize - 1, through: 0, by: -1) {
            bytes.append(UInt8((address >> (8 * i)) & 0xFF))
        }
        bytes.append(contentsOf: data)
        let checksum = computeChecksum(bytes)
        bytes.append(checksum)
        return type.rawValue + bytes.map { String(format: "%02X", $0) }.joined()
    }
}
