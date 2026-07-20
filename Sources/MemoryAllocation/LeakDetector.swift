// LeakDetector.swift
// MemoryAllocation
//
// Memory leak detection utilities

/// Memory leak detector
///
/// Detects memory leaks by tracking net allocations over time.
///
/// Example:
/// ```swift
/// let detector = LeakDetector()
///
/// for _ in 0..<100 {
///     let array = Array(repeating: 0, count: 1000)
///     _ = array.count
/// }
///
/// if detector.hasLeaks() {
///     print("Detected \(detector.netAllocations) leaked allocations")
/// }
/// ```
public final class LeakDetector: Sendable {
    private let baseline: AllocationStats

    /// Initialize a leak detector
    ///
    /// Captures baseline allocation statistics at initialization.
    public init() {
        #if os(Linux)
            AllocationStats.startTracking()
        #endif
        self.baseline = AllocationStats.capture()
    }

    /// Check if there are any memory leaks
    ///
    /// - Returns: True if net allocations have increased since initialization
    public func hasLeaks() -> Bool {
        netAllocations > 0
    }

    /// Get the number of net allocations since initialization
    ///
    /// Positive values indicate potential leaks.
    public var netAllocations: Int {
        let current = AllocationStats.capture()
        let delta = AllocationStats.delta(from: baseline, to: current)
        return delta.netAllocations
    }

    /// Get the number of net bytes allocated since initialization
    ///
    /// Positive values indicate potential memory leaks.
    public var netBytes: Int {
        let current = AllocationStats.capture()
        let delta = AllocationStats.delta(from: baseline, to: current)
        return delta.bytesAllocated
    }

    /// Get current allocation delta from baseline
    ///
    /// - Returns: Allocation statistics delta from initialization
    public func delta() -> AllocationStats {
        let current = AllocationStats.capture()
        return AllocationStats.delta(from: baseline, to: current)
    }

    /// Assert that no leaks have occurred
    ///
    /// - Parameter file: Source file location
    /// - Parameter line: Source line location
    /// - Throws: `LeakError` if leaks are detected
    public func assertNoLeaks(
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let net = netAllocations
        guard net == 0 else {
            throw LeakError.leaksDetected(
                allocations: net,
                bytes: netBytes,
                file: file,
                line: line
            )
        }
    }
}

/// Leak detection error
public enum LeakError: Error, CustomStringConvertible {
    /// Memory leaks were detected
    case leaksDetected(allocations: Int, bytes: Int, file: StaticString, line: UInt)

    public var description: String {
        switch self {
        case .leaksDetected(let allocations, let bytes, let file, let line):
            return """
                Memory leak detected at \(file):\(line)
                Net allocations: \(allocations)
                Net bytes: \(bytes)
                """
        }
    }
}
