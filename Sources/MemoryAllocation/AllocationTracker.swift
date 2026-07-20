// AllocationTracker.swift
// MemoryAllocation
//
// Convenient API for tracking allocations in code blocks

/// Allocation tracker for measuring memory allocations
///
/// Provides convenient methods for tracking allocations around code blocks.
///
/// Example:
/// ```swift
/// let stats = AllocationTracker.measure {
///     let array = Array(repeating: 0, count: 1000)
///     return array.count
/// }
/// print("Allocated \(stats.bytesAllocated) bytes")
/// ```
public enum AllocationTracker {
    /// Measure allocations for a synchronous closure
    ///
    /// - Parameter operation: The operation to measure
    /// - Returns: Allocation statistics for the operation
    /// - Throws: Rethrows any error from the operation
    public static func measure<T>(
        _ operation: () throws -> T
    ) rethrows -> (result: T, stats: AllocationStats) {
        #if os(Linux)
            AllocationStats.startTracking()
        #endif

        let start = AllocationStats.capture()
        let result = try operation()
        let end = AllocationStats.capture()

        let stats = AllocationStats.delta(from: start, to: end)
        return (result, stats)
    }

    /// Measure allocations for an async closure
    ///
    /// - Parameter operation: The async operation to measure
    /// - Returns: Allocation statistics for the operation
    /// - Throws: Rethrows any error from the operation
    public static func measure<T>(
        _ operation: () async throws -> T
    ) async rethrows -> (result: T, stats: AllocationStats) {
        #if os(Linux)
            AllocationStats.startTracking()
        #endif

        let start = AllocationStats.capture()
        let result = try await operation()
        let end = AllocationStats.capture()

        let stats = AllocationStats.delta(from: start, to: end)
        return (result, stats)
    }

    /// Measure allocations for a throwing closure, discarding the result
    ///
    /// - Parameter operation: The operation to measure
    /// - Returns: Allocation statistics for the operation
    /// - Throws: Rethrows any error from the operation
    public static func measure(
        _ operation: () throws -> Void
    ) rethrows -> AllocationStats {
        #if os(Linux)
            AllocationStats.startTracking()
        #endif

        let start = AllocationStats.capture()
        try operation()
        let end = AllocationStats.capture()

        return AllocationStats.delta(from: start, to: end)
    }

    /// Measure allocations for an async throwing closure, discarding the result
    ///
    /// - Parameter operation: The async operation to measure
    /// - Returns: Allocation statistics for the operation
    /// - Throws: Rethrows any error from the operation
    public static func measure(
        _ operation: () async throws -> Void
    ) async rethrows -> AllocationStats {
        #if os(Linux)
            AllocationStats.startTracking()
        #endif

        let start = AllocationStats.capture()
        try await operation()
        let end = AllocationStats.capture()

        return AllocationStats.delta(from: start, to: end)
    }
}
