// DiffEngineTests.swift
// StrataTests

import XCTest
@testable import Strata

final class DiffEngineTests: XCTestCase {

    // MARK: - Happy Path Tests

    func testIdenticalData() {
        let data = Data([0x01, 0x02, 0x03])
        let result = DiffEngine.diff(old: data, new: data)
        XCTAssertTrue(result.isIdentical)
        XCTAssertEqual(result.operations.count, 1)
        if case .equal(let oldR, let newR) = result.operations.first {
            XCTAssertEqual(oldR, 0..<3)
            XCTAssertEqual(newR, 0..<3)
        } else {
            XCTFail("Expected .equal operation")
        }
    }

    func testCompletelyDifferent() {
        let old = Data([0x01, 0x02])
        let new = Data([0xFE, 0xFD])
        let result = DiffEngine.diff(old: old, new: new)
        XCTAssertFalse(result.isIdentical)
        XCTAssertFalse(result.operations.isEmpty)
    }

    func testInsertionDiff() {
        let old = Data([0x01, 0x03])
        let new = Data([0x01, 0x02, 0x03])
        let result = DiffEngine.diff(old: old, new: new)
        XCTAssertFalse(result.isIdentical)
        var hasInsert = false
        for op in result.operations {
            if case .insert = op { hasInsert = true }
        }
        XCTAssertTrue(hasInsert)
    }

    func testDeletionDiff() {
        let old = Data([0x01, 0x02, 0x03])
        let new = Data([0x01, 0x03])
        let result = DiffEngine.diff(old: old, new: new)
        XCTAssertFalse(result.isIdentical)
        var hasDelete = false
        for op in result.operations {
            if case .delete = op { hasDelete = true }
        }
        XCTAssertTrue(hasDelete)
    }

    func testModificationDiff() {
        let old = Data([0x01, 0x02, 0x03])
        let new = Data([0x01, 0xFF, 0x03])
        let result = DiffEngine.diff(old: old, new: new)
        XCTAssertFalse(result.isIdentical)
    }

    func testSingleByteDiff() {
        let old = Data([0x01])
        let new = Data([0x02])
        let result = DiffEngine.diff(old: old, new: new)
        XCTAssertFalse(result.isIdentical)
    }

    func testKnownSequence() {
        let old = Data([0x41, 0x42, 0x43, 0x44]) // ABCD
        let new = Data([0x41, 0x43, 0x44, 0x45]) // ACDE
        let result = DiffEngine.diff(old: old, new: new)
        XCTAssertFalse(result.isIdentical)
        // A is equal, B is deleted, CD equal, E is inserted
        XCTAssertGreaterThan(result.operations.count, 1)
    }

    // MARK: - Edge Cases

    func testEmptyBothInputs() {
        let result = DiffEngine.diff(old: Data(), new: Data())
        XCTAssertTrue(result.isIdentical)
        XCTAssertTrue(result.operations.isEmpty)
    }

    func testEmptyOld() {
        let new = Data([0x01, 0x02])
        let result = DiffEngine.diff(old: Data(), new: new)
        XCTAssertFalse(result.isIdentical)
        var hasInsert = false
        for op in result.operations {
            if case .insert = op { hasInsert = true }
        }
        XCTAssertTrue(hasInsert)
    }

    func testEmptyNew() {
        let old = Data([0x01, 0x02])
        let result = DiffEngine.diff(old: old, new: Data())
        XCTAssertFalse(result.isIdentical)
        var hasDelete = false
        for op in result.operations {
            if case .delete = op { hasDelete = true }
        }
        XCTAssertTrue(hasDelete)
    }

    func testSymmetry() {
        let a = Data([0x01, 0x02, 0x03])
        let b = Data([0x01, 0xFF, 0x03])
        let ab = DiffEngine.diff(old: a, new: b)
        let ba = DiffEngine.diff(old: b, new: a)
        // Both should be non-identical and have the same number of operations
        XCTAssertFalse(ab.isIdentical)
        XCTAssertFalse(ba.isIdentical)
        XCTAssertEqual(ab.operations.count, ba.operations.count)
    }

    func testLargerSequence() {
        let old = Data(0..<64)
        var new = Data(0..<64)
        new[32] = 0xFF
        new.insert(0xAA, at: 16)
        let result = DiffEngine.diff(old: old, new: new)
        XCTAssertFalse(result.isIdentical)
    }
}
