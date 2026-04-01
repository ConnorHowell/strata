// SearchEngineTests.swift
// StrataTests

import XCTest
@testable import Strata

// MARK: - Linear Search and toLower Tests

final class SearchEngineTests: XCTestCase {

    // MARK: - toLower

    func testToLowerUppercaseLetters() {
        XCTAssertEqual(SearchEngine.toLower(0x41), 0x61) // A -> a
        XCTAssertEqual(SearchEngine.toLower(0x5A), 0x7A) // Z -> z
        XCTAssertEqual(SearchEngine.toLower(0x57), 0x77) // W -> w
    }

    func testToLowerLowercasePassthrough() {
        XCTAssertEqual(SearchEngine.toLower(0x61), 0x61) // a -> a
        XCTAssertEqual(SearchEngine.toLower(0x7A), 0x7A) // z -> z
    }

    func testToLowerNonAlphaPassthrough() {
        XCTAssertEqual(SearchEngine.toLower(0x00), 0x00)
        XCTAssertEqual(SearchEngine.toLower(0x30), 0x30) // '0'
        XCTAssertEqual(SearchEngine.toLower(0xFF), 0xFF)
        XCTAssertEqual(SearchEngine.toLower(0x20), 0x20) // space
    }

    // MARK: - Linear Search: Basic

    func testLinearSearchExactMatch() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03, 0x04]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0x02, 0x03]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 4, pattern: pattern, from: 0),
            1
        )
    }

    func testLinearSearchAtStart() {
        let table = PieceTable(data: Data([0xAA, 0xBB, 0xCC]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA, 0xBB]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0),
            0
        )
    }

    func testLinearSearchAtEnd() {
        let table = PieceTable(data: Data([0x01, 0x02, 0xAA, 0xBB]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA, 0xBB]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 4, pattern: pattern, from: 0),
            2
        )
    }

    func testLinearSearchNoMatch() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xFF]),
            mask: nil, direction: .forward
        )
        XCTAssertNil(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0)
        )
    }

    func testLinearSearchFromOffset() {
        let table = PieceTable(data: Data([0xAA, 0xBB, 0xAA, 0xBB]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA, 0xBB]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 4, pattern: pattern, from: 1),
            2
        )
    }

    func testLinearSearchDoesNotWrap() {
        let table = PieceTable(data: Data([0xAA, 0x00, 0x00]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .forward
        )
        XCTAssertNil(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 1)
        )
    }

    func testLinearSearchEmptyPattern() {
        let table = PieceTable(data: Data([0x01, 0x02]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data(),
            mask: nil, direction: .forward
        )
        XCTAssertNil(
            SearchEngine.linearSearch(in: table, length: 2, pattern: pattern, from: 0)
        )
    }

    func testLinearSearchPatternLargerThanData() {
        let table = PieceTable(data: Data([0x01]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0x01, 0x02]),
            mask: nil, direction: .forward
        )
        XCTAssertNil(
            SearchEngine.linearSearch(in: table, length: 1, pattern: pattern, from: 0)
        )
    }

    // MARK: - Linear Search: Case Insensitive

    func testLinearSearchCaseInsensitiveUpperInFile() {
        let table = PieceTable(data: Data([0x57, 0x56, 0x57])) // WVW
        let pattern = SearchPattern(
            mode: .textString, data: Data([0x57, 0x56, 0x57]),
            mask: nil, direction: .forward, caseSensitive: false
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0),
            0
        )
    }

    func testLinearSearchCaseInsensitiveLowerInPattern() {
        let table = PieceTable(data: Data([0x57, 0x56, 0x57])) // WVW
        let pattern = SearchPattern(
            mode: .textString, data: Data([0x77, 0x76, 0x77]),
            mask: nil, direction: .forward, caseSensitive: false
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0),
            0
        )
    }

    func testLinearSearchCaseInsensitiveMixedCase() {
        let hello = Data("Hello".utf8)
        let table = PieceTable(data: hello)
        let pattern = SearchPattern(
            mode: .textString, data: Data("hELLO".utf8),
            mask: nil, direction: .forward, caseSensitive: false
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(
                in: table, length: hello.count, pattern: pattern, from: 0
            ),
            0
        )
    }

    func testLinearSearchCaseSensitiveRejectsMismatch() {
        let table = PieceTable(data: Data([0x57, 0x56, 0x57])) // WVW
        let pattern = SearchPattern(
            mode: .textString, data: Data([0x77, 0x76, 0x77]),
            mask: nil, direction: .forward, caseSensitive: true
        )
        XCTAssertNil(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0)
        )
    }

    func testLinearSearchCaseInsensitiveNonAlpha() {
        let table = PieceTable(data: Data([0x01, 0x20, 0xFF]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0x01, 0x20, 0xFF]),
            mask: nil, direction: .forward, caseSensitive: false
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0),
            0
        )
    }

    // MARK: - Linear Search: Wildcard Mask

    func testLinearSearchWithMask() {
        let table = PieceTable(data: Data([0xAA, 0xBB, 0xCC]))
        let pattern = SearchPattern(
            mode: .hexValues,
            data: Data([0x00, 0xBB, 0x00]),
            mask: Data([0x00, 0xFF, 0x00]),
            direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0),
            0
        )
    }

    func testLinearSearchMaskNoMatch() {
        let table = PieceTable(data: Data([0xAA, 0xCC, 0xDD]))
        let pattern = SearchPattern(
            mode: .hexValues,
            data: Data([0x00, 0xBB, 0x00]),
            mask: Data([0x00, 0xFF, 0x00]),
            direction: .forward
        )
        XCTAssertNil(
            SearchEngine.linearSearch(in: table, length: 3, pattern: pattern, from: 0)
        )
    }
}

// MARK: - Wrapping Search, Counting, and Pattern Parsing Tests

final class SearchEngineWrappingTests: XCTestCase {

    // MARK: - Wrapping Search

    func testWrappingSearchForward() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03, 0x01]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0x01]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.wrappingSearch(in: table, length: 4, pattern: pattern, from: 1),
            3
        )
    }

    func testWrappingSearchForwardWrapsAround() {
        let table = PieceTable(data: Data([0xAA, 0x00, 0x00]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.wrappingSearch(in: table, length: 3, pattern: pattern, from: 1),
            0
        )
    }

    func testWrappingSearchBackward() {
        let table = PieceTable(data: Data([0xAA, 0x00, 0x00, 0xAA]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .backward
        )
        XCTAssertEqual(
            SearchEngine.wrappingSearch(in: table, length: 4, pattern: pattern, from: 2),
            0
        )
    }

    func testWrappingSearchBackwardWraps() {
        let table = PieceTable(data: Data([0x00, 0x00, 0xAA]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .backward
        )
        XCTAssertEqual(
            SearchEngine.wrappingSearch(in: table, length: 3, pattern: pattern, from: 0),
            2
        )
    }

    func testWrappingSearchCaseInsensitive() {
        let table = PieceTable(data: Data([0x00, 0x57, 0x56, 0x57])) // .WVW
        let pattern = SearchPattern(
            mode: .textString, data: Data([0x77, 0x76, 0x77]), // wvw
            mask: nil, direction: .forward, caseSensitive: false
        )
        XCTAssertEqual(
            SearchEngine.wrappingSearch(in: table, length: 4, pattern: pattern, from: 0),
            1
        )
    }

    // MARK: - Count Matches

    func testCountMatchesSingle() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0x02]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(SearchEngine.countMatches(in: table, length: 3, pattern: pattern), 1)
    }

    func testCountMatchesMultiple() {
        let table = PieceTable(data: Data([0xAA, 0xBB, 0xAA, 0xBB, 0xAA]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(SearchEngine.countMatches(in: table, length: 5, pattern: pattern), 3)
    }

    func testCountMatchesZero() {
        let table = PieceTable(data: Data([0x01, 0x02, 0x03]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xFF]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(SearchEngine.countMatches(in: table, length: 3, pattern: pattern), 0)
    }

    func testCountMatchesCaseInsensitive() {
        let table = PieceTable(data: Data([0x41, 0x62, 0x41, 0x62, 0x41, 0x62]))
        let pattern = SearchPattern(
            mode: .textString, data: Data([0x61, 0x62]),
            mask: nil, direction: .forward, caseSensitive: false
        )
        XCTAssertEqual(SearchEngine.countMatches(in: table, length: 6, pattern: pattern), 3)
    }

    func testCountMatchesRespectsMaxCount() {
        let table = PieceTable(data: Data(repeating: 0xAA, count: 256))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(
            SearchEngine.countMatches(in: table, length: 256, pattern: pattern, maxCount: 100),
            100
        )
    }

    func testCountMatchesEmptyPattern() {
        let table = PieceTable(data: Data([0x01]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data(),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(SearchEngine.countMatches(in: table, length: 1, pattern: pattern), 0)
    }

    // MARK: - Match Index

    func testMatchIndexFirst() {
        let table = PieceTable(data: Data([0xAA, 0x00, 0xAA]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(SearchEngine.matchIndex(in: table, length: 3, pattern: pattern, at: 0), 1)
    }

    func testMatchIndexSecond() {
        let table = PieceTable(data: Data([0xAA, 0x00, 0xAA]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(SearchEngine.matchIndex(in: table, length: 3, pattern: pattern, at: 2), 2)
    }

    func testMatchIndexNoMatchAtPos() {
        let table = PieceTable(data: Data([0xAA, 0x00, 0xAA]))
        let pattern = SearchPattern(
            mode: .hexValues, data: Data([0xAA]),
            mask: nil, direction: .forward
        )
        XCTAssertEqual(SearchEngine.matchIndex(in: table, length: 3, pattern: pattern, at: 1), 1)
    }

    // MARK: - Hex Pattern Parsing

    func testParseHexPatternSimple() {
        XCTAssertEqual(FindReplacePanel.parseHexPattern("FF 00 AB"), Data([0xFF, 0x00, 0xAB]))
    }

    func testParseHexPatternNoSpaces() {
        XCTAssertEqual(FindReplacePanel.parseHexPattern("FF00AB"), Data([0xFF, 0x00, 0xAB]))
    }

    func testParseHexPatternInvalid() {
        XCTAssertNil(FindReplacePanel.parseHexPattern("GG"))
        XCTAssertNil(FindReplacePanel.parseHexPattern("F"))
        XCTAssertNil(FindReplacePanel.parseHexPattern(""))
    }

    // MARK: - Wildcard Pattern Parsing

    func testParseWildcardPattern() {
        let result = FindReplacePanel.parseWildcardPattern("FF ?? AB")
        XCTAssertEqual(result?.data, Data([0xFF, 0x00, 0xAB]))
        XCTAssertEqual(result?.mask, Data([0xFF, 0x00, 0xFF]))
    }

    func testParseWildcardPatternAllWild() {
        let result = FindReplacePanel.parseWildcardPattern("?? ??")
        XCTAssertEqual(result?.data, Data([0x00, 0x00]))
        XCTAssertEqual(result?.mask, Data([0x00, 0x00]))
    }

    func testParseWildcardPatternInvalid() {
        XCTAssertNil(FindReplacePanel.parseWildcardPattern(""))
        XCTAssertNil(FindReplacePanel.parseWildcardPattern("GG"))
        XCTAssertNil(FindReplacePanel.parseWildcardPattern("FFF"))
    }

    // MARK: - SearchPattern Default Values

    func testSearchPatternDefaultCaseSensitive() {
        let pattern = SearchPattern(
            mode: .textString, data: Data([0x41]),
            mask: nil, direction: .forward
        )
        XCTAssertTrue(pattern.caseSensitive)
    }

    func testSearchPatternExplicitCaseInsensitive() {
        let pattern = SearchPattern(
            mode: .textString, data: Data([0x41]),
            mask: nil, direction: .forward, caseSensitive: false
        )
        XCTAssertFalse(pattern.caseSensitive)
    }
}
