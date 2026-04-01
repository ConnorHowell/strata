// FindCryptEngineTests.swift
// Strata - macOS Hex Editor

@testable import Strata
import XCTest

final class FindCryptEngineTests: XCTestCase {

    // MARK: - Known Constants

    /// AES S-box (first 16 bytes for quick reference).
    private static let aesSboxPrefix: [UInt8] = [
        0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5,
        0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
    ]

    /// Full AES S-box (256 bytes).
    private static let aesSbox: [UInt8] = [
        0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5,
        0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
        0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0,
        0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
        0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC,
        0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
        0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A,
        0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
        0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0,
        0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
        0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B,
        0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
        0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85,
        0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
        0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5,
        0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
        0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17,
        0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
        0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88,
        0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
        0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C,
        0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
        0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9,
        0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
        0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6,
        0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
        0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E,
        0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
        0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94,
        0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
        0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68,
        0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16,
    ]

    /// TEA/XTEA delta constant.
    private static let teaDelta: [UInt8] = [0x9E, 0x37, 0x79, 0xB9]

    // MARK: - Helper

    private func makeSignature(
        name: String, category: String, bytes: [UInt8], elementSize: Int
    ) -> CryptoSignature {
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return CryptoSignature(
            name: name, category: category,
            hexBytes: hex, elementSize: elementSize
        )
    }

    // MARK: - Tests

    func testAESSboxDetection() {
        let sig = makeSignature(
            name: "AES S-box", category: "Block Cipher",
            bytes: Self.aesSbox, elementSize: 1
        )
        // Embed S-box in random data
        var data = Data(repeating: 0xAA, count: 100)
        data.append(contentsOf: Self.aesSbox)
        data.append(Data(repeating: 0xBB, count: 100))

        let matches = FindCryptEngine.scan(data: data, signatures: [sig])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].offset, 100)
        XCTAssertEqual(matches[0].signatureName, "AES S-box")
        XCTAssertEqual(matches[0].confidence, 1.0)
        XCTAssertEqual(matches[0].endianness, "native")
    }

    func testSmallSignatureDetection() {
        let sig = makeSignature(
            name: "TEA Delta", category: "Block Cipher",
            bytes: Self.teaDelta, elementSize: 4
        )
        var data = Data(repeating: 0x00, count: 50)
        data.append(contentsOf: Self.teaDelta)
        data.append(Data(repeating: 0x00, count: 50))

        let matches = FindCryptEngine.scan(data: data, signatures: [sig])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].offset, 50)
        XCTAssertEqual(matches[0].signatureName, "TEA Delta")
    }

    func testSwappedEndianDetection() {
        // TEA delta in big endian is 9E3779B9, swapped (LE) is B979379E
        let sig = makeSignature(
            name: "TEA Delta", category: "Block Cipher",
            bytes: Self.teaDelta, elementSize: 4
        )
        let swapped: [UInt8] = [0xB9, 0x79, 0x37, 0x9E]
        var data = Data(repeating: 0x00, count: 20)
        data.append(contentsOf: swapped)
        data.append(Data(repeating: 0x00, count: 20))

        let matches = FindCryptEngine.scan(data: data, signatures: [sig])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].endianness, "swapped")
        XCTAssertEqual(matches[0].confidence, 1.0)
    }

    func testNoFalsePositivesOnRandom() {
        let sig = makeSignature(
            name: "AES S-box", category: "Block Cipher",
            bytes: Self.aesSbox, elementSize: 1
        )
        // Deterministic pseudo-random data (not the S-box)
        var data = Data(count: 1024)
        for i in 0..<1024 {
            data[i] = UInt8((i * 7 + 13) & 0xFF)
        }
        let matches = FindCryptEngine.scan(data: data, signatures: [sig])
        XCTAssertTrue(matches.isEmpty)
    }

    func testMultipleAlgorithms() {
        let aesSig = makeSignature(
            name: "AES S-box", category: "Block Cipher",
            bytes: Self.aesSbox, elementSize: 1
        )
        let teaSig = makeSignature(
            name: "TEA Delta", category: "Block Cipher",
            bytes: Self.teaDelta, elementSize: 4
        )

        var data = Data(repeating: 0x00, count: 50)
        data.append(contentsOf: Self.aesSbox)
        data.append(Data(repeating: 0x00, count: 50))
        data.append(contentsOf: Self.teaDelta)
        data.append(Data(repeating: 0x00, count: 50))

        let matches = FindCryptEngine.scan(data: data, signatures: [aesSig, teaSig])
        XCTAssertEqual(matches.count, 2)
        let names = Set(matches.map(\.signatureName))
        XCTAssertTrue(names.contains("AES S-box"))
        XCTAssertTrue(names.contains("TEA Delta"))
    }

    func testSignatureAtDataBoundary() {
        let sig = makeSignature(
            name: "TEA Delta", category: "Block Cipher",
            bytes: Self.teaDelta, elementSize: 4
        )
        // Signature at the very end
        var data = Data(repeating: 0x00, count: 100)
        data.append(contentsOf: Self.teaDelta)

        let matches = FindCryptEngine.scan(data: data, signatures: [sig])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].offset, 100)
    }

    func testSignatureAtStart() {
        let sig = makeSignature(
            name: "TEA Delta", category: "Block Cipher",
            bytes: Self.teaDelta, elementSize: 4
        )
        var data = Data(Self.teaDelta)
        data.append(Data(repeating: 0x00, count: 100))

        let matches = FindCryptEngine.scan(data: data, signatures: [sig])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].offset, 0)
    }

    func testEmptyData() {
        let sig = makeSignature(
            name: "AES S-box", category: "Block Cipher",
            bytes: Self.aesSbox, elementSize: 1
        )
        let matches = FindCryptEngine.scan(data: Data(), signatures: [sig])
        XCTAssertTrue(matches.isEmpty)
    }

    func testHexToBytes() {
        let bytes = FindCryptEngine.hexToBytes("48656c6c6f")
        XCTAssertEqual(bytes, [0x48, 0x65, 0x6C, 0x6C, 0x6F])
    }

    func testHexToBytesInvalid() {
        XCTAssertNil(FindCryptEngine.hexToBytes("XYZ"))
        XCTAssertNil(FindCryptEngine.hexToBytes("123"))  // odd length
    }

    func testChaChaConstant() {
        let constant = Array("expand 32-byte k".utf8)
        let sig = makeSignature(
            name: "ChaCha20 Constant", category: "Stream Cipher",
            bytes: constant, elementSize: 1
        )
        var data = Data(repeating: 0xCC, count: 64)
        data.append(contentsOf: constant)
        data.append(Data(repeating: 0xDD, count: 64))

        let matches = FindCryptEngine.scan(data: data, signatures: [sig])
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].signatureName, "ChaCha20 Constant")
    }

    // MARK: - Database Tests

    func testLoadSignatureDatabase() {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(
            forResource: "FindCryptSignatures", withExtension: "json"
        ) else {
            // Skip if not in test bundle
            return
        }
        let sigs = FindCryptEngine.loadSignatures(from: url)
        XCTAssertGreaterThan(sigs.count, 100)
        // Verify all hex strings are parseable
        for sig in sigs {
            XCTAssertNotNil(
                FindCryptEngine.hexToBytes(sig.hexBytes),
                "Failed to parse hex for \(sig.name)"
            )
        }
    }
}
