// Measurement.swift
// TestingPerformance
//
// Performance measurement primitives for Swift Testing

import Real_Primitives

extension TestingPerformance {
    /// Statistical performance measurement containing multiple duration samples.
    ///
    /// `Measurement` stores the results of running a performance test multiple times
    /// and provides statistical metrics like median, mean, percentiles, and standard deviation.
    ///
    /// ## Overview
    ///
    /// Create measurements using ``TestingPerformance/measure(warmup:iterations:operation:)-4kv1g``:
    ///
    /// ```swift
    /// let (result, measurement) = TestingPerformance.measure(iterations: 100) {
    ///     expensiveOperation()
    /// }
    ///
    /// print("Median: \(measurement.median)")
    /// print("p95: \(measurement.p95)")
    /// ```
    ///
    /// ## Statistical Metrics
    ///
    /// - **Median** (``median``): Middle value, resistant to outliers
    /// - **Mean** (``mean``): Average of all measurements
    /// - **Percentiles** (``p50``, ``p75``, ``p90``, ``p95``, ``p99``, ``p999``): Values at specific percentiles
    /// - **Min/Max** (``min``, ``max``): Fastest and slowest iterations
    /// - **Standard Deviation** (``standardDeviation``): Measure of variation
    ///
    /// ## Comparison
    ///
    /// Measurements are `Comparable` by median value:
    ///
    /// ```swift
    /// if measurement1 < measurement2 {
    ///     print("measurement1 was faster")
    /// }
    /// ```
    ///
    /// ## Serialization
    ///
    /// Measurements conform to `Codable` for easy serialization:
    ///
    /// ```swift
    /// let encoder = JSONEncoder()
    /// encoder.outputFormatting = .prettyPrinted
    /// let data = try encoder.encode(measurement)
    /// ```
    ///
    /// ## Topics
    ///
    /// ### Creating Measurements
    ///
    /// - ``init(durations:)``
    /// - ``durations``
    ///
    /// ### Central Tendency
    ///
    /// - ``median``
    /// - ``mean``
    /// - ``min``
    /// - ``max``
    ///
    /// ### Percentiles
    ///
    /// - ``p50``
    /// - ``p75``
    /// - ``p90``
    /// - ``p95``
    /// - ``p99``
    /// - ``p999``
    /// - ``percentile(_:)``
    ///
    /// ### Variability
    ///
    /// - ``standardDeviation``
    public struct Measurement: Sendable, Codable {
        /// All measured durations from individual test iterations.
        ///
        /// Each duration represents a single execution of the measured operation.
        /// The order matches the execution order, though most statistical metrics
        /// are order-independent.
        public let durations: [Duration]

        /// Creates a measurement from an array of durations.
        ///
        /// - Parameter durations: Individual duration measurements from test iterations
        ///
        /// Example:
        /// ```swift
        /// let measurement = Measurement(durations: [
        ///     .milliseconds(10),
        ///     .milliseconds(11),
        ///     .milliseconds(10)
        /// ])
        /// ```
        public init(durations: [Duration]) {
            self.durations = durations
        }
    }
}

// MARK: - Comparable

extension TestingPerformance.Measurement: Comparable {
    /// Compares measurements by median duration
    public static func < (
        lhs: TestingPerformance.Measurement,
        rhs: TestingPerformance.Measurement
    ) -> Bool {
        lhs.median < rhs.median
    }

    /// Compares measurements by median duration
    public static func == (
        lhs: TestingPerformance.Measurement,
        rhs: TestingPerformance.Measurement
    ) -> Bool {
        lhs.median == rhs.median
    }
}

extension TestingPerformance.Measurement {
    /// Minimum duration across all iterations.
    ///
    /// Returns the fastest single iteration. Useful for identifying best-case performance.
    ///
    /// Returns `.zero` if no durations were measured.
    public var min: Duration {
        durations.min() ?? .zero
    }

    /// Maximum duration across all iterations.
    ///
    /// Returns the slowest single iteration. Useful for identifying worst-case performance
    /// or outliers caused by system interference.
    ///
    /// Returns `.zero` if no durations were measured.
    public var max: Duration {
        durations.max() ?? .zero
    }

    /// Median duration (50th percentile).
    ///
    /// The median is the middle value when all durations are sorted. It's resistant to
    /// outliers and generally preferred over mean for performance testing.
    ///
    /// This is the default metric used by performance traits.
    ///
    /// Returns `.zero` if no durations were measured.
    public var median: Duration {
        percentile(0.5)
    }

    /// Average (mean) duration across all iterations.
    ///
    /// The mean is calculated as the sum of all durations divided by the count.
    /// It's affected by outliers, which may or may not be desirable depending on your use case.
    ///
    /// Returns `.zero` if no durations were measured.
    public var mean: Duration {
        guard !durations.isEmpty else { return .zero }
        let total = durations.reduce(Duration.zero, +)
        return total / durations.count
    }

    /// 50th percentile duration (same as ``median``).
    ///
    /// Provided for consistency with other percentile metrics.
    public var p50: Duration {
        percentile(0.5)
    }

    /// 75th percentile duration.
    ///
    /// 75% of iterations completed faster than this duration.
    public var p75: Duration {
        percentile(0.75)
    }

    /// 90th percentile duration.
    ///
    /// 90% of iterations completed faster than this duration.
    public var p90: Duration {
        percentile(0.90)
    }

    /// 95th percentile duration.
    ///
    /// 95% of iterations completed faster than this duration. Commonly used for
    /// service-level objectives (SLOs) in production systems.
    public var p95: Duration {
        percentile(0.95)
    }

    /// 99th percentile duration.
    ///
    /// 99% of iterations completed faster than this duration. Useful for identifying
    /// tail latency in latency-sensitive systems.
    public var p99: Duration {
        percentile(0.99)
    }

    /// 99.9th percentile duration.
    ///
    /// 99.9% of iterations completed faster than this duration. Identifies extreme outliers.
    public var p999: Duration {
        percentile(0.999)
    }

    /// Calculate a specific percentile.
    ///
    /// - Parameter p: Percentile to calculate, from 0.0 (minimum) to 1.0 (maximum)
    /// - Returns: Duration at the specified percentile, or `.zero` if no durations
    ///
    /// Example:
    /// ```swift
    /// let p90 = measurement.percentile(0.90)  // 90th percentile
    /// let p50 = measurement.percentile(0.50)  // Same as median
    /// ```
    public func percentile(_ p: Double) -> Duration {
        guard !durations.isEmpty else { return .zero }
        let sorted = durations.sorted()
        let index = Int(Double(sorted.count) * p)
        let clampedIndex = Swift.min(index, sorted.count - 1)
        return sorted[clampedIndex]
    }

    /// Standard deviation of duration measurements.
    ///
    /// Measures the amount of variation in the measurements. Lower standard deviation
    /// indicates more consistent performance.
    ///
    /// Returns `.zero` if fewer than 2 measurements are available.
    public var standardDeviation: Duration {
        guard durations.count > 1 else { return .zero }
        let meanSeconds = mean.inSeconds
        let variance =
            durations.reduce(0.0) { acc, duration in
                let diff = duration.inSeconds - meanSeconds
                return acc + (diff * diff)
            } / Double(durations.count - 1)
        return .seconds(variance.squareRoot())
    }
}

// MARK: - Measurement API

// swift-format-ignore: AmbiguousTrailingClosureOverload
extension TestingPerformance {
    /// Measure performance of an operation
    ///
    /// Runs the operation multiple times with optional warmup iterations,
    /// collecting timing data for statistical analysis.
    ///
    /// Example:
    /// ```swift
    /// let measurement = TestingPerformance.measure(warmup: 3, iterations: 100) {
    ///     numbers.sum()
    /// }
    /// print("Median: \(TestingPerformance.formatDuration(measurement.median))")
    /// ```
    @discardableResult
    public static func measure<T>(
        warmup: Int = 0,
        iterations: Int = 10,
        operation: () -> T
    ) -> (result: T, measurement: TestingPerformance.Measurement) {
        // Warmup
        for _ in 0..<warmup {
            _ = operation()
        }

        // Measure
        var durations: [Duration] = []
        durations.reserveCapacity(iterations)
        var lastResult: T?

        for _ in 0..<iterations {
            let start = ContinuousClock.now
            lastResult = operation()
            let end = ContinuousClock.now
            durations.append(end - start)
        }

        // Force unwrap is safe here because iterations must be > 0 for valid measurements
        return (lastResult!, TestingPerformance.Measurement(durations: durations))
    }

    /// Measure performance of an async operation
    @discardableResult
    public static func measure<T>(
        warmup: Int = 0,
        iterations: Int = 10,
        operation: () async throws -> T
    ) async rethrows -> (result: T, measurement: TestingPerformance.Measurement) {
        // Warmup
        for _ in 0..<warmup {
            _ = try await operation()
        }

        // Measure
        var durations: [Duration] = []
        durations.reserveCapacity(iterations)
        var lastResult: T?

        for _ in 0..<iterations {
            let start = ContinuousClock.now
            lastResult = try await operation()
            let end = ContinuousClock.now
            durations.append(end - start)
        }

        // Force unwrap is safe here because iterations must be > 0 for valid measurements
        return (lastResult!, TestingPerformance.Measurement(durations: durations))
    }

    /// Single-shot timing measurement
    ///
    /// Times a single execution without statistical analysis.
    /// Useful for quick timing checks or when operations are too expensive to repeat.
    ///
    /// Example:
    /// ```swift
    /// let (result, duration) = TestingPerformance.time {
    ///     expensiveComputation()
    /// }
    /// ```
    @discardableResult
    public static func time<T>(operation: () -> T) -> (result: T, duration: Duration) {
        let start = ContinuousClock.now
        let result = operation()
        let end = ContinuousClock.now
        return (result, end - start)
    }

    /// Single-shot timing measurement for async operations
    @discardableResult
    public static func time<T>(
        operation: () async throws -> T
    ) async rethrows -> (result: T, duration: Duration) {
        let start = ContinuousClock.now
        let result = try await operation()
        let end = ContinuousClock.now
        return (result, end - start)
    }
}

// MARK: - Duration Formatting

extension TestingPerformance {
    /// Format options for duration display
    public enum Format {
        /// Automatically select the most appropriate unit
        case auto
        /// Display in nanoseconds (ns)
        case nanoseconds
        /// Display in microseconds (µs)
        case microseconds
        /// Display in milliseconds (ms)
        case milliseconds
        /// Display in seconds (s)
        case seconds

        func format(_ duration: Duration) -> String {
            switch self {
            case .auto:
                let seconds = duration.inSeconds
                if seconds < 0.000001 {
                    return formatNumber(duration.inNanoseconds, decimals: 2) + "ns"
                } else if seconds < 0.001 {
                    return formatNumber(duration.inMicroseconds, decimals: 2) + "µs"
                } else if seconds < 1.0 {
                    return formatNumber(duration.inMilliseconds, decimals: 2) + "ms"
                } else {
                    return formatNumber(seconds, decimals: 2) + "s"
                }

            case .nanoseconds:
                return formatNumber(duration.inNanoseconds, decimals: 2) + "ns"

            case .microseconds:
                return formatNumber(duration.inMicroseconds, decimals: 2) + "µs"

            case .milliseconds:
                return formatNumber(duration.inMilliseconds, decimals: 2) + "ms"

            case .seconds:
                return formatNumber(duration.inSeconds, decimals: 2) + "s"
            }
        }

        private func formatNumber(_ value: Double, decimals: Int) -> String {
            let multiplier = Double.math.pow(10.0, Double(decimals))
            let rounded = (value * multiplier).rounded() / multiplier

            let integerPart = Int(rounded)
            let fractionalPart = rounded - Double(integerPart)

            if fractionalPart == 0 {
                return "\(integerPart).\(String(repeating: "0", count: decimals))"
            }

            var fractionStr = "\(Int((fractionalPart * multiplier).rounded()))"
            while fractionStr.count < decimals {
                fractionStr = "0" + fractionStr
            }

            return "\(integerPart).\(fractionStr)"
        }
    }
}

extension TestingPerformance {
    /// Format a duration for performance display
    ///
    /// Automatically selects appropriate unit (ns, µs, ms, s).
    ///
    /// Example:
    /// ```swift
    /// let formatted = TestingPerformance.formatDuration(.milliseconds(5.82))
    /// // "5.82ms"
    /// ```
    public static func formatDuration(
        _ duration: Duration,
        _ format: TestingPerformance.Format = .auto
    ) -> String {
        format.format(duration)
    }
}

// MARK: - Duration arithmetic
//
// Note: Duration division by BinaryInteger is provided by Swift's standard library.
// The standard library implementation uses Int128 for exact arithmetic internally.
// See: https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Duration.swift
//
// No custom division operator needed - Swift handles this correctly!
