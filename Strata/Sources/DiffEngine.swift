// DiffEngine.swift
// Strata - macOS Hex Editor

import Foundation

// MARK: - DiffOperation

/// Describes a single diff operation between two byte sequences.
public enum DiffOperation: Equatable {
    /// Bytes are identical in both sequences.
    case equal(oldRange: Range<Int>, newRange: Range<Int>)
    /// Bytes were inserted in the new sequence.
    case insert(newRange: Range<Int>)
    /// Bytes were deleted from the old sequence.
    case delete(oldRange: Range<Int>)
    /// Bytes were replaced (delete + insert at the same position).
    case replace(oldRange: Range<Int>, newRange: Range<Int>)
}

// MARK: - DiffResult

/// The result of comparing two byte sequences.
public struct DiffResult {
    /// The ordered list of diff operations.
    public let operations: [DiffOperation]

    /// Whether the two sequences are identical.
    public var isIdentical: Bool {
        operations.allSatisfy {
            if case .equal = $0 { return true }
            return false
        }
    }
}

// MARK: - DiffEngine

/// Pure-Swift Myers diff algorithm for comparing byte sequences.
public enum DiffEngine {

    // MARK: - Public API

    /// Computes the diff between two byte sequences using the Myers algorithm.
    ///
    /// - Parameters:
    ///   - old: The original byte data.
    ///   - new: The modified byte data.
    /// - Returns: A `DiffResult` containing the list of operations.
    public static func diff(old: Data, new: Data) -> DiffResult {
        let oldBytes = Array(old)
        let newBytes = Array(new)
        let edits = myersDiff(old: oldBytes, new: newBytes)
        let operations = consolidateEdits(edits, oldLen: oldBytes.count, newLen: newBytes.count)
        return DiffResult(operations: operations)
    }

    // MARK: - Private

    private enum EditType {
        case insert(newIndex: Int)
        case delete(oldIndex: Int)
        case equal(oldIndex: Int, newIndex: Int)
    }

    private static func myersDiff(old: [UInt8], new: [UInt8]) -> [EditType] {
        let n = old.count
        let m = new.count

        if n == 0 && m == 0 { return [] }
        if n == 0 {
            return (0..<m).map { .insert(newIndex: $0) }
        }
        if m == 0 {
            return (0..<n).map { .delete(oldIndex: $0) }
        }

        let maxD = n + m
        let offset = maxD
        let size = 2 * maxD + 1
        var v = Array(repeating: 0, count: size)
        var trace: [[Int]] = []

        outerLoop: for d in 0...maxD {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                let idx = k + offset
                var x: Int
                if d == 0 {
                    x = 0
                } else if k == -d || (k != d && v[idx - 1] < v[idx + 1]) {
                    x = v[idx + 1]
                } else {
                    x = v[idx - 1] + 1
                }
                var y = x - k
                while x < n && y < m && old[x] == new[y] {
                    x += 1
                    y += 1
                }
                v[idx] = x
                if x >= n && y >= m {
                    break outerLoop
                }
            }
        }

        return backtrack(trace: trace, old: old, new: new, offset: offset)
    }

    private static func backtrack(
        trace: [[Int]],
        old: [UInt8],
        new: [UInt8],
        offset: Int
    ) -> [EditType] {
        var x = old.count
        var y = new.count
        var edits: [EditType] = []

        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y
            let idx = k + offset

            var prevK: Int
            if d == 0 {
                prevK = 0
            } else if k == -d || (k != d && v[idx - 1] < v[idx + 1]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevX: Int
            if d == 0 {
                prevX = 0
            } else {
                prevX = trace[d - 1][prevK + offset]
            }
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                edits.append(.equal(oldIndex: x, newIndex: y))
            }

            if d > 0 {
                if x == prevX {
                    y -= 1
                    edits.append(.insert(newIndex: y))
                } else {
                    x -= 1
                    edits.append(.delete(oldIndex: x))
                }
            }
        }

        return edits.reversed()
    }

    private static func consolidateEdits(
        _ edits: [EditType],
        oldLen: Int,
        newLen: Int
    ) -> [DiffOperation] {
        var operations: [DiffOperation] = []
        var i = 0

        while i < edits.count {
            switch edits[i] {
            case .equal(let oi, let ni):
                var endOi = oi + 1
                var endNi = ni + 1
                i += 1
                while i < edits.count,
                      case .equal(let nextOi, let nextNi) = edits[i],
                      nextOi == endOi,
                      nextNi == endNi {
                    endOi += 1
                    endNi += 1
                    i += 1
                }
                operations.append(.equal(oldRange: oi..<endOi, newRange: ni..<endNi))

            case .delete(let oi):
                var endOi = oi + 1
                i += 1
                while i < edits.count, case .delete(let nextOi) = edits[i], nextOi == endOi {
                    endOi += 1
                    i += 1
                }
                if i < edits.count, case .insert(let ni) = edits[i] {
                    var endNi = ni + 1
                    i += 1
                    while i < edits.count, case .insert(let nextNi) = edits[i], nextNi == endNi {
                        endNi += 1
                        i += 1
                    }
                    operations.append(.replace(oldRange: oi..<endOi, newRange: ni..<endNi))
                } else {
                    operations.append(.delete(oldRange: oi..<endOi))
                }

            case .insert(let ni):
                var endNi = ni + 1
                i += 1
                while i < edits.count, case .insert(let nextNi) = edits[i], nextNi == endNi {
                    endNi += 1
                    i += 1
                }
                operations.append(.insert(newRange: ni..<endNi))
            }
        }

        return operations
    }
}
