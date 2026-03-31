// PieceTableTests.swift
// StrataTests

import XCTest
@testable import Strata

final class PieceTableTests: XCTestCase {

    // MARK: - Insert Tests

    func testInsertAtBeginning() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        table.insert(at: 0, bytes: Data([0xFF]))
        XCTAssertEqual(table.totalLength, 4)
        XCTAssertEqual(table.byte(at: 0), 0xFF)
        XCTAssertEqual(table.byte(at: 1), 0x01)
    }

    func testInsertAtEnd() {
        let table = PieceTable(data: Data([0x01, 0x02]))
        table.insert(at: 2, bytes: Data([0xFF]))
        XCTAssertEqual(table.totalLength, 3)
        XCTAssertEqual(table.byte(at: 2), 0xFF)
    }

    func testInsertInMiddle() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        table.insert(at: 1, bytes: Data([0xAA, 0xBB]))
        XCTAssertEqual(table.totalLength, 5)
        XCTAssertEqual(table.byte(at: 0), 0x01)
        XCTAssertEqual(table.byte(at: 1), 0xAA)
        XCTAssertEqual(table.byte(at: 2), 0xBB)
        XCTAssertEqual(table.byte(at: 3), 0x02)
    }

    func testInsertAtInvalidOffset() {
        let table = PieceTable(data: Data([0x01]))
        table.insert(at: 100, bytes: Data([0xFF]))
        XCTAssertEqual(table.totalLength, 2)
        XCTAssertEqual(table.byte(at: 1), 0xFF)
    }

    func testInsertEmptyBytes() {
        let table = PieceTable(data: Data([0x01]))
        table.insert(at: 0, bytes: Data())
        XCTAssertEqual(table.totalLength, 1)
    }

    // MARK: - Overwrite Tests

    func testOverwriteBytes() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        table.overwrite(at: 1, bytes: Data([0xFF]))
        XCTAssertEqual(table.totalLength, 3)
        XCTAssertEqual(table.byte(at: 0), 0x01)
        XCTAssertEqual(table.byte(at: 1), 0xFF)
        XCTAssertEqual(table.byte(at: 2), 0x03)
    }

    func testOverwriteAtBoundary() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        table.overwrite(at: 2, bytes: Data([0xFF]))
        XCTAssertEqual(table.byte(at: 2), 0xFF)
    }

    func testOverwriteBeyondEnd() {
        let table = PieceTable(data: Data([0x01, 0x02]))
        table.overwrite(at: 5, bytes: Data([0xFF]))
        XCTAssertEqual(table.totalLength, 2)
    }

    func testOverwriteMultipleBytes() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03, 0x04]))
        table.overwrite(at: 1, bytes: Data([0xAA, 0xBB]))
        XCTAssertEqual(table.byte(at: 0), 0x01)
        XCTAssertEqual(table.byte(at: 1), 0xAA)
        XCTAssertEqual(table.byte(at: 2), 0xBB)
        XCTAssertEqual(table.byte(at: 3), 0x04)
    }

    // MARK: - Delete Tests

    func testDeleteRange() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03, 0x04]))
        table.delete(range: 1..<3)
        XCTAssertEqual(table.totalLength, 2)
        XCTAssertEqual(table.byte(at: 0), 0x01)
        XCTAssertEqual(table.byte(at: 1), 0x04)
    }

    func testDeleteEmptyRange() {
        let table = PieceTable(data: Data([0x01, 0x02]))
        table.delete(range: 1..<1)
        XCTAssertEqual(table.totalLength, 2)
    }

    func testDeleteBeyondEnd() {
        let table = PieceTable(data: Data([0x01, 0x02]))
        table.delete(range: 0..<100)
        XCTAssertEqual(table.totalLength, 0)
    }

    // MARK: - Undo/Redo Tests

    func testUndoInsert() {
        let table = PieceTable(data: Data([0x01, 0x02]))
        table.insert(at: 1, bytes: Data([0xFF]))
        XCTAssertEqual(table.totalLength, 3)
        table.undoManager.undo()
        XCTAssertEqual(table.totalLength, 2)
        XCTAssertEqual(table.byte(at: 0), 0x01)
        XCTAssertEqual(table.byte(at: 1), 0x02)
    }

    func testRedoInsert() {
        let table = PieceTable(data: Data([0x01]))
        table.insert(at: 0, bytes: Data([0xFF]))
        table.undoManager.undo()
        XCTAssertEqual(table.totalLength, 1)
        table.undoManager.redo()
        XCTAssertEqual(table.totalLength, 2)
        XCTAssertEqual(table.byte(at: 0), 0xFF)
    }

    func testUndoOverwrite() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        table.overwrite(at: 1, bytes: Data([0xFF]))
        XCTAssertEqual(table.byte(at: 1), 0xFF)
        table.undoManager.undo()
        XCTAssertEqual(table.byte(at: 1), 0x02)
    }

    func testUndoRedoSequence() {
        let undoMgr = UndoManager()
        undoMgr.groupsByEvent = false
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]), undoManager: undoMgr)
        // Insert AA at beginning: [AA, 01, 02, 03] length=4
        undoMgr.beginUndoGrouping()
        table.insert(at: 0, bytes: Data([0xAA]))
        undoMgr.endUndoGrouping()
        XCTAssertEqual(table.totalLength, 4)
        // Overwrite at position 2: [AA, 01, BB, 03] length=4
        undoMgr.beginUndoGrouping()
        table.overwrite(at: 2, bytes: Data([0xBB]))
        undoMgr.endUndoGrouping()
        XCTAssertEqual(table.totalLength, 4)
        // Undo overwrite: [AA, 01, 02, 03] length=4
        undoMgr.undo()
        XCTAssertEqual(table.totalLength, 4)
        XCTAssertEqual(table.byte(at: 2), 0x02)
        // Undo insert: [01, 02, 03] length=3
        undoMgr.undo()
        XCTAssertEqual(table.totalLength, 3)
        // Redo insert: [AA, 01, 02, 03] length=4
        undoMgr.redo()
        XCTAssertEqual(table.totalLength, 4)
        XCTAssertEqual(table.byte(at: 0), 0xAA)
    }

    // MARK: - Access Tests

    func testByteAccess() {
        let table = PieceTable(data: Data([0xDE, 0xAD, 0xBE, 0xEF]))
        XCTAssertEqual(table[0], 0xDE)
        XCTAssertEqual(table[3], 0xEF)
        XCTAssertNil(table[4])
        XCTAssertNil(table[-1])
    }

    func testBytesInRange() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03, 0x04]))
        let slice = table.bytes(in: 1..<3)
        XCTAssertEqual(slice, Data([0x02, 0x03]))
    }

    func testTotalLength() {
        let table = PieceTable(data: Data(count: 100))
        XCTAssertEqual(table.totalLength, 100)
        table.insert(at: 50, bytes: Data(count: 10))
        XCTAssertEqual(table.totalLength, 110)
        table.delete(range: 0..<20)
        XCTAssertEqual(table.totalLength, 90)
    }

    // MARK: - Edge Cases

    func testEmptyPieceTable() {
        let table = PieceTable()
        XCTAssertEqual(table.totalLength, 0)
        XCTAssertNil(table.byte(at: 0))
        table.insert(at: 0, bytes: Data([0xFF]))
        XCTAssertEqual(table.totalLength, 1)
        XCTAssertEqual(table.byte(at: 0), 0xFF)
    }

    func testLargeFileSimulation() {
        let size = 10_000
        let data = Data(repeating: 0xAB, count: size)
        let table = PieceTable(data: data)
        for i in stride(from: 0, to: size, by: 100) {
            table.overwrite(at: i, bytes: Data([0xCD]))
        }
        XCTAssertEqual(table.totalLength, size)
        XCTAssertEqual(table.byte(at: 0), 0xCD)
        XCTAssertEqual(table.byte(at: 1), 0xAB)
        XCTAssertEqual(table.byte(at: 100), 0xCD)
    }

    func testSequentialInserts() {
        let table = PieceTable()
        for i: UInt8 in 0..<50 {
            table.insert(at: Int(i), bytes: Data([i]))
        }
        XCTAssertEqual(table.totalLength, 50)
        for i: UInt8 in 0..<50 {
            XCTAssertEqual(table.byte(at: Int(i)), i)
        }
    }

    func testInterleavedOperations() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03, 0x04, 0x05]))
        table.insert(at: 2, bytes: Data([0xAA]))
        table.delete(range: 0..<1)
        table.overwrite(at: 0, bytes: Data([0xFF]))
        XCTAssertEqual(table.byte(at: 0), 0xFF)
        XCTAssertEqual(table.totalLength, 5)
    }

    func testDirtyFlag() {
        let table = PieceTable(data: Data([0x01]))
        XCTAssertFalse(table.isDirty)
        table.insert(at: 0, bytes: Data([0xFF]))
        XCTAssertTrue(table.isDirty)
        table.markClean()
        XCTAssertFalse(table.isDirty)
    }
}
