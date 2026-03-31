// SRecordTests.swift
// StrataTests

import XCTest
@testable import Strata

final class SRecordTests: XCTestCase {

    // MARK: - Parse Tests

    func testParseS1Record() throws {
        let srec = "S1130000285F245F2212226A000424290008237C2A\n" +
                   "S5030001FB\n" +
                   "S9030000FC\n"
        let records = try SRecord.parse(srec)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].type, .s1)
        XCTAssertEqual(records[0].address, 0x0000)
        XCTAssertEqual(records[0].data.count, 16)
    }

    func testParseS2Record() throws {
        let srec = "S20801000028466745DC\n" +
                   "S5030001FB\n" +
                   "S804010000FA\n"
        let records = try SRecord.parse(srec)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].type, .s2)
        XCTAssertEqual(records[0].address, 0x010000)
        XCTAssertEqual(records[0].data, Data([0x28, 0x46, 0x67, 0x45]))
    }

    func testParseS3Record() throws {
        let srec = "S3090100000028466745DB\n" +
                   "S70501000000F9\n"
        let records = try SRecord.parse(srec)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].type, .s3)
        XCTAssertEqual(records[0].address, 0x01000000)
    }

    func testParseMultipleRecords() throws {
        let srec = """
        S0030000FC
        S1130000285F245F2212226A000424290008237C2A
        S1130010285F245F2212226A000424290008237C1A
        S5030002FA
        S9030000FC
        """
        let records = try SRecord.parse(srec)
        XCTAssertEqual(records.count, 5)
        XCTAssertEqual(records[0].type, .s0)
        XCTAssertEqual(records[1].type, .s1)
        XCTAssertEqual(records[2].type, .s1)
        XCTAssertEqual(records[3].type, .s5)
        XCTAssertEqual(records[4].type, .s9)
    }

    // MARK: - Round Trip

    func testRoundTrip() throws {
        let originalData = Data([0x28, 0x5F, 0x24, 0x5F, 0x22, 0x12, 0x22, 0x6A,
                                 0x00, 0x04, 0x24, 0x29, 0x00, 0x08, 0x23, 0x7C])
        let srecString = SRecord.fromData(originalData)
        let records = try SRecord.parse(srecString)
        let reconstructed = SRecord.toData(records)
        XCTAssertEqual(reconstructed, originalData)
    }

    func testRoundTripLargerData() throws {
        let originalData = Data(0..<48)
        let srecString = SRecord.fromData(originalData)
        let records = try SRecord.parse(srecString)
        let reconstructed = SRecord.toData(records)
        XCTAssertEqual(reconstructed, originalData)
    }

    // MARK: - Error Cases

    func testBadChecksum() {
        let srec = "S1130000285F245F2212226A000424290008237CFF\n"
        XCTAssertThrowsError(try SRecord.parse(srec)) { error in
            guard case SRecordError.badChecksum = error else {
                XCTFail("Expected badChecksum error, got \(error)")
                return
            }
        }
    }

    func testInvalidRecordType() {
        let srec = "S6030000FC\n"
        XCTAssertThrowsError(try SRecord.parse(srec)) { error in
            guard case SRecordError.invalidRecordType = error else {
                XCTFail("Expected invalidRecordType error, got \(error)")
                return
            }
        }
    }

    func testMalformedLine() {
        let srec = "S1\n"
        XCTAssertThrowsError(try SRecord.parse(srec)) { error in
            guard case SRecordError.malformedLine = error else {
                XCTFail("Expected malformedLine error, got \(error)")
                return
            }
        }
    }

    func testEmptyInput() throws {
        let records = try SRecord.parse("")
        XCTAssertTrue(records.isEmpty)
    }

    func testMissingPrefix() {
        let srec = "X1130000285F245F2212226A000424290008237C2A\n"
        XCTAssertThrowsError(try SRecord.parse(srec)) { error in
            guard case SRecordError.missingPrefix = error else {
                XCTFail("Expected missingPrefix error, got \(error)")
                return
            }
        }
    }

    // MARK: - Address Width Tests

    func testAddressWidths() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])

        let s1 = SRecord.fromData(data, addressWidth: .bit16)
        XCTAssertTrue(s1.contains("S1"))
        let records1 = try SRecord.parse(s1)
        XCTAssertEqual(SRecord.toData(records1), data)

        let s2 = SRecord.fromData(data, addressWidth: .bit24)
        XCTAssertTrue(s2.contains("S2"))
        let records2 = try SRecord.parse(s2)
        XCTAssertEqual(SRecord.toData(records2), data)

        let s3 = SRecord.fromData(data, addressWidth: .bit32)
        XCTAssertTrue(s3.contains("S3"))
        let records3 = try SRecord.parse(s3)
        XCTAssertEqual(SRecord.toData(records3), data)
    }

    // MARK: - toData Tests

    func testToData() throws {
        let srec = "S1130000285F245F2212226A000424290008237C2A\n" +
                   "S9030000FC\n"
        let records = try SRecord.parse(srec)
        let data = SRecord.toData(records)
        XCTAssertEqual(data.count, 16)
        XCTAssertEqual(data[0], 0x28)
    }

    func testToDataEmpty() {
        let data = SRecord.toData([])
        XCTAssertTrue(data.isEmpty)
    }
}
