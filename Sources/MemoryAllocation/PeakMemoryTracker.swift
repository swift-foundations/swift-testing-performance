// PeakMemoryTracker.swift
// MemoryAllocation
//
// Peak memory usage tracking

import Synchronization

/// Peak memory tracker
///
/// Tracks the peak memory usage during program execution.
///
/// Example:
/// ```swift
/// let tracker = PeakMemoryTracker()
///
/// for i in 0..<100 {
///     let array = Array(repeating: 0, count: i * 100)
///     tracker.sample()
/// }
///
/// print("Peak memory: \(tracker.peakBytes) bytes")
/// print("Peak allocations: \(tracker.peakAllocations)")
/// ```
public final class PeakMemoryTracker: Sendable {
    private struct State: Sendable {
        var peakBytes: Int = 0
        var peakAllocations: Int = 0
        var samples: [AllocationStats] = []
    }

    private let state = Mutex<State>(State())
    private let baseline: AllocationStats

    /// Initialize a peak memory tracker
    public init() {
        #if os(Linux)
            AllocationStats.startTracking()
        #endif

        self.baseline = AllocationStats.capture()
    }

    /// Record a sample of current memory usage
    ///
    /// Call this periodically to track peak memory.
    public func sample() {
        let current = AllocationStats.capture()
        let delta = AllocationStats.delta(from: baseline, to: current)

        state.withLock { state in
            state.samples.append(delta)
            state.peakBytes = max(state.peakBytes, delta.bytesAllocated)
            state.peakAllocations = max(state.peakAllocations, delta.allocations)
        }
    }

    /// Peak bytes allocated since initialization
    public var peakBytes: Int {
        state.withLock { $0.peakBytes }
    }

    /// Peak number of allocations since initialization
    public var peakAllocations: Int {
        state.withLock { $0.peakAllocations }
    }

    /// All samples collected
    public var samples: [AllocationStats] {
        state.withLock { $0.samples }
    }

    /// Current memory usage
    public var current: AllocationStats {
        let current = AllocationStats.capture()
        return AllocationStats.delta(from: baseline, to: current)
    }

    /// Reset peak tracking
    ///
    /// Clears samples and resets peak values to current state.
    public func reset() {
        state.withLock { state in
            state.samples.removeAll()
            state.peakBytes = 0
            state.peakAllocations = 0
        }
    }

    /// Track peak memory during an operation
    ///
    /// Samples memory at regular intervals during the operation.
    ///
    /// - Parameters:
    ///   - sampleInterval: Number of iterations between samples
    ///   - operation: The operation to track
    /// - Returns: Peak allocation statistics and operation result
    public static func track<T>(
        sampleInterval: Int = 1,
        _ operation: (PeakMemoryTracker) throws -> T
    ) rethrows -> (result: T, peak: AllocationStats) {
        let tracker = PeakMemoryTracker()
        let result = try operation(tracker)

        return (
            result,
            AllocationStats(
                allocations: tracker.peakAllocations,
                deallocations: 0,
                bytesAllocated: tracker.peakBytes
            )
        )
    }

    /// Track peak memory during an async operation
    ///
    /// - Parameters:
    ///   - sampleInterval: Number of iterations between samples
    ///   - operation: The async operation to track
    /// - Returns: Peak allocation statistics and operation result
    public static func track<T>(
        sampleInterval: Int = 1,
        _ operation: (PeakMemoryTracker) async throws -> T
    ) async rethrows -> (result: T, peak: AllocationStats) {
        let tracker = PeakMemoryTracker()
        let result = try await operation(tracker)

        return (
            result,
            AllocationStats(
                allocations: tracker.peakAllocations,
                deallocations: 0,
                bytesAllocated: tracker.peakBytes
            )
        )
    }
}
