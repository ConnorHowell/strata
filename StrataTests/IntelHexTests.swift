// IntelHexTests.swift
// StrataTests

import XCTest
@testable import Strata

final class IntelHexTests: XCTestCase {

    // MARK: - Parse Tests

    func testParseSimpleDataRecord() throws {
        let hex = ":0300000002006E8D\n:00000001FF\n"
        let records = try IntelHex.parse(hex)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].type, .data)
        XCTAssertEqual(records[0].address, 0x0000)
        XCTAssertEqual(records[0].data, Data([0x02, 0x00, 0x6E]))
        XCTAssertEqual(records[1].type, .eof)
    }

    func testParseMultipleRecords() throws {
        let hex = """
        :10010000214601360121470136007EFE09D2190140
        :100110002146017E17C20001FF5F16002148011928
        :00000001FF
        """
        let records = try IntelHex.parse(hex)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].type, .data)
        XCTAssertEqual(records[0].data.count, 16)
        XCTAssertEqual(records[1].type, .data)
        XCTAssertEqual(records[1].data.count, 16)
        XCTAssertEqual(records[2].type, .eof)
    }

    func testParseExtendedAddress() throws {
        let hex = ":02000004FFFFFC\n:0100000042BD\n:00000001FF\n"
        let records = try IntelHex.parse(hex)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].type, .extendedLinearAddress)
    }

    func testParseEOFRecord() throws {
        let hex = ":00000001FF\n"
        let records = try IntelHex.parse(hex)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].type, .eof)
    }

    // MARK: - Round Trip

    func testRoundTrip() throws {
        let originalData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                                 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10])
        let hexString = IntelHex.fromData(originalData)
        let records = try IntelHex.parse(hexString)
        let reconstructed = IntelHex.toData(records)
        XCTAssertEqual(reconstructed, originalData)
    }

    func testRoundTripLargerData() throws {
        let originalData = Data(0..<64)
        let hexString = IntelHex.fromData(originalData)
        let records = try IntelHex.parse(hexString)
        let reconstructed = IntelHex.toData(records)
        XCTAssertEqual(reconstructed, originalData)
    }

    // MARK: - Error Cases

    func testBadChecksum() {
        let hex = ":0300000002006EFF\n"
        XCTAssertThrowsError(try IntelHex.parse(hex)) { error in
            guard case IntelHexError.badChecksum = error else {
                XCTFail("Expected badChecksum error, got \(error)")
                return
            }
        }
    }

    func testInvalidRecordType() {
        // Record type 0x09 is invalid
        let hex = ":0100000900F6\n"
        XCTAssertThrowsError(try IntelHex.parse(hex)) { error in
            guard case IntelHexError.invalidRecordType = error else {
                XCTFail("Expected invalidRecordType error, got \(error)")
                return
            }
        }
    }

    func testMalformedLine() {
        let hex = ":01\n"
        XCTAssertThrowsError(try IntelHex.parse(hex)) { error in
            guard case IntelHexError.malformedLine = error else {
                XCTFail("Expected malformedLine error, got \(error)")
                return
            }
        }
    }

    func testEmptyInput() throws {
        let records = try IntelHex.parse("")
        XCTAssertTrue(records.isEmpty)
    }

    func testMissingColon() {
        let hex = "0300000002006EA1\n"
        XCTAssertThrowsError(try IntelHex.parse(hex)) { error in
            guard case IntelHexError.missingStartCode = error else {
                XCTFail("Expected missingStartCode error, got \(error)")
                return
            }
        }
    }

    // MARK: - toData Tests

    func testToData() throws {
        let hex = ":0300000002006E8D\n:00000001FF\n"
        let records = try IntelHex.parse(hex)
        let data = IntelHex.toData(records)
        XCTAssertEqual(data, Data([0x02, 0x00, 0x6E]))
    }

    func testToDataEmpty() {
        let data = IntelHex.toData([])
        XCTAssertTrue(data.isEmpty)
    }
}
