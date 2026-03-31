// ChecksumEngineTests.swift
// StrataTests

import XCTest
@testable import Strata

final class ChecksumEngineTests: XCTestCase {

    // MARK: - CRC-16 Tests

    func testCRC16Empty() {
        let result = ChecksumEngine.compute(.crc16, data: Data())
        XCTAssertEqual(result, "0000")
    }

    func testCRC16KnownVector() {
        // CRC-16/ARC of "123456789" = 0xBB3D
        let data = "123456789".data(using: .ascii)!
        let result = ChecksumEngine.compute(.crc16, data: data)
        XCTAssertEqual(result, "bb3d")
    }

    // MARK: - CRC-32 Tests

    func testCRC32Empty() {
        let result = ChecksumEngine.compute(.crc32, data: Data())
        XCTAssertEqual(result, "00000000")
    }

    func testCRC32KnownVector() {
        // CRC-32 of "123456789" = 0xCBF43926
        let data = "123456789".data(using: .ascii)!
        let result = ChecksumEngine.compute(.crc32, data: data)
        XCTAssertEqual(result, "cbf43926")
    }

    func testCRC32SingleByte() {
        let data = Data([0x00])
        let result = ChecksumEngine.compute(.crc32, data: data)
        // CRC-32 of 0x00 = 0xD202EF8D
        XCTAssertEqual(result, "d202ef8d")
    }

    // MARK: - MD5 Tests

    func testMD5Empty() {
        let result = ChecksumEngine.compute(.md5, data: Data())
        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testMD5HelloWorld() {
        let data = "Hello, World!".data(using: .utf8)!
        let result = ChecksumEngine.compute(.md5, data: data)
        XCTAssertEqual(result, "65a8e27d8879283831b664bd8b7f0ad4")
    }

    func testMD5KnownVector() {
        let data = "abc".data(using: .ascii)!
        let result = ChecksumEngine.compute(.md5, data: data)
        XCTAssertEqual(result, "900150983cd24fb0d6963f7d28e17f72")
    }

    // MARK: - SHA-1 Tests

    func testSHA1Empty() {
        let result = ChecksumEngine.compute(.sha1, data: Data())
        XCTAssertEqual(result, "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    }

    func testSHA1KnownVector() {
        let data = "abc".data(using: .ascii)!
        let result = ChecksumEngine.compute(.sha1, data: data)
        XCTAssertEqual(result, "a9993e364706816aba3e25717850c26c9cd0d89d")
    }

    // MARK: - SHA-256 Tests

    func testSHA256Empty() {
        let result = ChecksumEngine.compute(.sha256, data: Data())
        XCTAssertEqual(result, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testSHA256KnownVector() {
        let data = "abc".data(using: .ascii)!
        let result = ChecksumEngine.compute(.sha256, data: data)
        XCTAssertEqual(result, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    // MARK: - Compute All Tests

    func testComputeAll() {
        let data = "test".data(using: .ascii)!
        let results = ChecksumEngine.computeAll(data: data)
        XCTAssertEqual(results.count, ChecksumType.allCases.count)
        for type in ChecksumType.allCases {
            XCTAssertNotNil(results[type])
            XCTAssertFalse(results[type]?.isEmpty ?? true)
        }
    }

    // MARK: - Large Data Test

    func testLargeData() {
        let data = Data(repeating: 0xAB, count: 100_000)
        let result = ChecksumEngine.compute(.sha256, data: data)
        XCTAssertEqual(result.count, 64) // SHA-256 is 64 hex chars
        XCTAssertFalse(result.isEmpty)
    }
}
