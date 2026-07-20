// AllocationProfiler.swift
// MemoryAllocation
//
// Allocation profiling with histograms and statistics

import Synchronization

/// Allocation profiler
///
/// Profiles memory allocations over multiple runs to generate statistics
/// and histograms.
///
/// Example:
/// ```swift
/// let profiler = AllocationProfiler()
///
/// for _ in 0..<100 {
///     profiler.profile {
///         let array = Array(repeating: 0, count: 1000)
///         _ = array.count
///     }
/// }
///
/// print("Mean: \(profiler.meanBytes) bytes")
/// print("Median: \(profiler.medianBytes) bytes")
/// print("P95: \(profiler.percentileBytes(95)) bytes")
/// ```
public final class AllocationProfiler: Sendable {
    private let measurements = Mutex<[AllocationStats]>([])

    /// Initialize an allocation profiler
    public init() {}

    /// Profile a single execution
    ///
    /// - Parameter operation: The operation to profile
    /// - Returns: The operation result
    /// - Throws: Rethrows any error from the operation
    @discardableResult
    public func profile<T>(
        _ operation: () throws -> T
    ) rethrows -> T {
        let (result, stats) = try AllocationTracker.measure(operation)

        measurements.withLock { m in
            m.append(stats)
        }

        return result
    }

    /// Profile a single async execution
    ///
    /// - Parameter operation: The async operation to profile
    /// - Returns: The operation result
    /// - Throws: Rethrows any error from the operation
    @discardableResult
    public func profile<T>(
        _ operation: () async throws -> T
    ) async rethrows -> T {
        let (result, stats) = try await AllocationTracker.measure(operation)

        measurements.withLock { m in
            m.append(stats)
        }

        return result
    }

    /// Number of profiled executions
    public var count: Int {
        measurements.withLock { $0.count }
    }

    /// All measurements
    public var allMeasurements: [AllocationStats] {
        measurements.withLock { $0 }
    }

    /// Mean bytes allocated across all executions
    public var meanBytes: Double {
        measurements.withLock { m in
            guard !m.isEmpty else { return 0 }
            let total = m.reduce(0) { $0 + $1.bytesAllocated }
            return Double(total) / Double(m.count)
        }
    }

    /// Median bytes allocated
    public var medianBytes: Int {
        percentileBytes(50)
    }

    /// Calculate percentile for bytes allocated
    ///
    /// - Parameter percentile: Percentile to calculate (0-100)
    /// - Returns: Bytes allocated at the given percentile
    public func percentileBytes(_ percentile: Int) -> Int {
        measurements.withLock { m in
            guard !m.isEmpty else { return 0 }

            let sorted = m.map(\.bytesAllocated).sorted()
            let index = Int(Double(sorted.count) * Double(percentile) / 100.0)
            return sorted[min(index, sorted.count - 1)]
        }
    }

    /// Mean allocations across all executions
    public var meanAllocations: Double {
        measurements.withLock { m in
            guard !m.isEmpty else { return 0 }
            let total = m.reduce(0) { $0 + $1.allocations }
            return Double(total) / Double(m.count)
        }
    }

    /// Median allocations
    public var medianAllocations: Int {
        percentileAllocations(50)
    }

    /// Calculate percentile for allocation count
    ///
    /// - Parameter percentile: Percentile to calculate (0-100)
    /// - Returns: Allocation count at the given percentile
    public func percentileAllocations(_ percentile: Int) -> Int {
        measurements.withLock { m in
            guard !m.isEmpty else { return 0 }

            let sorted = m.map(\.allocations).sorted()
            let index = Int(Double(sorted.count) * Double(percentile) / 100.0)
            return sorted[min(index, sorted.count - 1)]
        }
    }

    /// Generate allocation histogram
    ///
    /// - Parameter buckets: Number of buckets in the histogram
    /// - Returns: Histogram of allocation counts
    public func histogram(buckets: Int = 10) -> AllocationHistogram {
        measurements.withLock { m in
            let bytes = m.map(\.bytesAllocated)
            return AllocationHistogram(values: bytes, buckets: buckets)
        }
    }

    /// Reset profiler
    ///
    /// Clears all measurements.
    public func reset() {
        measurements.withLock { m in
            m.removeAll()
        }
    }
}

/// Allocation histogram
public struct AllocationHistogram: Sendable {
    /// Histogram buckets
    public let buckets: [Bucket]

    /// A histogram bucket
    public struct Bucket: Sendable {
        /// Lower bound of the bucket (inclusive)
        public let lowerBound: Int

        /// Upper bound of the bucket (exclusive)
        public let upperBound: Int

        /// Number of values in this bucket
        public let count: Int

        /// Frequency as a percentage (0-100)
        public let frequency: Double

        public init(lowerBound: Int, upperBound: Int, count: Int, frequency: Double) {
            self.lowerBound = lowerBound
            self.upperBound = upperBound
            self.count = count
            self.frequency = frequency
        }
    }

    public init(values: [Int], buckets bucketCount: Int) {
        guard !values.isEmpty, bucketCount > 0 else {
            self.buckets = []
            return
        }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let range = maxValue - minValue
        let bucketSize = Swift.max(1, range / bucketCount)

        var buckets: [Bucket] = []
        let total = Double(values.count)

        for i in 0..<bucketCount {
            let lower = minValue + (i * bucketSize)
            let upper = (i == bucketCount - 1) ? maxValue + 1 : minValue + ((i + 1) * bucketSize)

            let count = values.filter { $0 >= lower && $0 < upper }.count
            let frequency = (Double(count) / total) * 100.0

            buckets.append(
                Bucket(
                    lowerBound: lower,
                    upperBound: upper,
                    count: count,
                    frequency: frequency
                )
            )
        }

        self.buckets = buckets
    }
}
