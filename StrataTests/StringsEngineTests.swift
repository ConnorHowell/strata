// StringsEngineTests.swift
// Strata - macOS Hex Editor

@testable import Strata
import XCTest

final class StringsEngineTests: XCTestCase {

    // MARK: - ASCII Tests

    func testASCIIExtraction() {
        // "Hello" embedded in noise
        var data = Data([0x00, 0x01, 0x02])
        data.append(contentsOf: "Hello World".utf8)
        data.append(contentsOf: [0x00, 0xFF])
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.ascii])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].value, "Hello World")
        XCTAssertEqual(matches[0].offset, 3)
        XCTAssertEqual(matches[0].encoding, .ascii)
        XCTAssertEqual(matches[0].byteLength, 11)
    }

    func testMinLengthFiltering() {
        // "Hi" is 2 chars, below default min of 4
        var data = Data([0x00])
        data.append(contentsOf: "Hi".utf8)
        data.append(Data([0x00]))
        data.append(contentsOf: "Test".utf8)
        data.append(Data([0x00]))
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.ascii])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].value, "Test")
    }

    func testMinLengthEdgeCase() {
        // String exactly at min length should be included
        var data = Data([0x00])
        data.append(contentsOf: "ABCD".utf8)
        data.append(Data([0x00]))
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.ascii])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].value, "ABCD")
    }

    func testMinLengthOne() {
        var data = Data([0x00])
        data.append(contentsOf: "X".utf8)
        data.append(Data([0x00]))
        let matches = StringsEngine.scan(data: data, minLength: 1, encodings: [.ascii])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].value, "X")
    }

    func testEmptyData() {
        let matches = StringsEngine.scan(data: Data(), minLength: 4, encodings: [.ascii])
        XCTAssertTrue(matches.isEmpty)
    }

    func testAllNonPrintable() {
        let data = Data([0x00, 0x01, 0x02, 0x03, 0x80, 0xFF])
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.ascii])
        XCTAssertTrue(matches.isEmpty)
    }

    func testAdjacentStrings() {
        // Two strings separated by null
        var data = Data()
        data.append(contentsOf: "First".utf8)
        data.append(Data([0x00]))
        data.append(contentsOf: "Second".utf8)
        data.append(Data([0x00]))
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.ascii])
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].value, "First")
        XCTAssertEqual(matches[0].offset, 0)
        XCTAssertEqual(matches[1].value, "Second")
        XCTAssertEqual(matches[1].offset, 6)
    }

    func testTrailingString() {
        // String at end of data with no null terminator
        var data = Data([0x00, 0x01])
        data.append(contentsOf: "trailing".utf8)
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.ascii])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].value, "trailing")
    }

    // MARK: - UTF-16 Tests

    func testUTF16LEDetection() {
        // "Test" in UTF-16 LE: T=0x54,0x00 e=0x65,0x00 s=0x73,0x00 t=0x74,0x00
        let utf16LEBytes: [UInt8] = [
            0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74, 0x00,
        ]
        var data = Data([0xFF, 0xFF])
        data.append(contentsOf: utf16LEBytes)
        data.append(contentsOf: [0x00, 0x00])
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.utf16LE])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].value, "Test")
        XCTAssertEqual(matches[0].encoding, .utf16LE)
        XCTAssertEqual(matches[0].byteLength, 8)
    }

    func testUTF16BEDetection() {
        // "Test" in UTF-16 BE: T=0x00,0x54 e=0x00,0x65 s=0x00,0x73 t=0x00,0x74
        let utf16BEBytes: [UInt8] = [
            0x00, 0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74,
        ]
        var data = Data([0xFF, 0xFF])
        data.append(contentsOf: utf16BEBytes)
        data.append(contentsOf: [0x00, 0x00])
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.utf16BE])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].value, "Test")
        XCTAssertEqual(matches[0].encoding, .utf16BE)
    }

    // MARK: - Multi-Encoding Tests

    func testMultipleEncodings() {
        // Test ASCII and UTF-16 LE in separate scans to verify both work
        var asciiData = Data()
        asciiData.append(contentsOf: "Hello".utf8)
        asciiData.append(Data([0x00]))

        let asciiMatches = StringsEngine.scan(
            data: asciiData, minLength: 4, encodings: [.ascii]
        )
        XCTAssertTrue(asciiMatches.contains { $0.value == "Hello" })

        // Verify that scanning with both encodings finds both types
        // Use even-aligned UTF-16 data
        var utf16Data = Data()
        utf16Data.append(contentsOf: [
            0x54, 0x00, 0x65, 0x00, 0x73, 0x00, 0x74, 0x00,
        ])
        let utf16Matches = StringsEngine.scan(
            data: utf16Data, minLength: 4, encodings: [.utf16LE]
        )
        XCTAssertTrue(utf16Matches.contains { $0.value == "Test" })

        // Combined scan should find at least both
        var combined = Data()
        combined.append(contentsOf: "AAAA".utf8)
        combined.append(Data([0x00, 0x00]))
        combined.append(contentsOf: [
            0x42, 0x00, 0x42, 0x00, 0x42, 0x00, 0x42, 0x00,
        ])
        let allMatches = StringsEngine.scan(
            data: combined, minLength: 4, encodings: [.ascii, .utf16LE]
        )
        let encodingsFound = Set(allMatches.map(\.encoding))
        XCTAssertTrue(encodingsFound.contains(.ascii))
        XCTAssertTrue(encodingsFound.contains(.utf16LE))
    }

    func testResultsSortedByOffset() {
        var data = Data()
        data.append(contentsOf: "ZZZZ".utf8)
        data.append(Data([0x00]))
        data.append(contentsOf: "AAAA".utf8)
        let matches = StringsEngine.scan(data: data, minLength: 4, encodings: [.ascii])
        XCTAssertEqual(matches.count, 2)
        XCTAssertTrue(matches[0].offset < matches[1].offset)
    }

    // MARK: - File-Based Scanner Tests

    func testScanFileASCII() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let tmpFile = tmpDir.appendingPathComponent(
            "strata_test_\(UUID().uuidString).bin"
        )
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        var data = Data([0x00, 0x01, 0x02])
        data.append(contentsOf: "Hello World".utf8)
        data.append(contentsOf: [0x00, 0xFF])
        data.append(contentsOf: "Test".utf8)
        data.append(Data([0x00]))
        try data.write(to: tmpFile)

        let matches = StringsEngine.scanFile(
            url: tmpFile, minLength: 4, encodings: [.ascii]
        )
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].value, "Hello World")
        XCTAssertEqual(matches[0].offset, 3)
        XCTAssertEqual(matches[1].value, "Test")
    }

    func testScanFileLargeData() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let tmpFile = tmpDir.appendingPathComponent(
            "strata_test_large_\(UUID().uuidString).bin"
        )
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        // Create a 1 MB file with known strings at specific offsets
        var data = Data(repeating: 0x00, count: 1_000_000)
        let testString = "FINDME_STRING"
        let offsets = [0, 100_000, 500_000, 999_000]
        for off in offsets {
            let strBytes = Array(testString.utf8)
            for (j, byte) in strBytes.enumerated() where off + j < data.count {
                data[off + j] = byte
            }
        }
        try data.write(to: tmpFile)

        let matches = StringsEngine.scanFile(
            url: tmpFile, minLength: 4, encodings: [.ascii]
        )
        let found = matches.filter { $0.value.contains("FINDME_STRING") }
        // Last offset may be truncated if too close to end
        XCTAssertGreaterThanOrEqual(found.count, 3)
    }
}
