// TestingPerformance.swift
// TestingPerformance
//
// Main namespace and core types

import Real_Primitives

/// Namespace for performance testing utilities integrated with Swift Testing.
///
/// TestingPerformance provides comprehensive tools for measuring, analyzing, and
/// enforcing performance requirements in your Swift tests. All features work with
/// zero external dependencies, relying only on Swift stdlib and platform APIs.
///
/// ## Overview
///
/// Use TestingPerformance to:
/// - Measure execution time with statistical analysis
/// - Track memory allocations during test execution
/// - Compare performance across runs to detect regressions
/// - Enforce performance budgets with declarative traits
/// - Generate beautifully formatted performance reports
///
/// ## Basic Usage
///
/// The simplest way to measure performance is with the `.timed()` trait:
///
/// ```swift
/// import Testing
/// import TestingPerformance
///
/// @Test(.timed())
/// func arraySum() {
///     let numbers = Array(1...10_000)
///     _ = numbers.reduce(0, +)
/// }
/// ```
///
/// For manual measurement without traits:
///
/// ```swift
/// @Test
/// func manualMeasurement() {
///     let (result, measurement) = TestingPerformance.measure {
///         expensiveOperation()
///     }
///
///     TestingPerformance.printPerformance("operation", measurement)
///     #expect(measurement.median < .milliseconds(10))
/// }
/// ```
///
/// ## Performance Budgets
///
/// Enforce maximum execution time to prevent performance regressions:
///
/// ```swift
/// @Test(.timed(threshold: .milliseconds(5)))
/// func mustBeFast() {
///     criticalOperation()
/// }
/// ```
///
/// ## Topics
///
/// ### Measurement
///
/// - ``measure(warmup:iterations:operation:)-4kv1g``
/// - ``measure(warmup:iterations:operation:)-32h7a``
/// - ``time(operation:)-2qtt``
/// - ``time(operation:)-21jsp``
///
/// ### Assertions
///
/// - ``expectPerformance(lessThan:warmup:iterations:metric:operation:)-5llun``
/// - ``expectPerformance(lessThan:warmup:iterations:metric:operation:)-9621g``
/// - ``expectNoRegression(current:baseline:tolerance:metric:)``
///
/// ### Reporting
///
/// - ``printPerformance(_:_:allocations:)``
/// - ``printComparisonReport(_:)``
///
/// ### Error Handling
///
/// - ``Error``
public enum TestingPerformance {}

// MARK: - Error Types

extension TestingPerformance {
    /// Errors thrown during performance testing operations.
    ///
    /// These errors provide detailed information about performance violations,
    /// including actual vs expected values and contextual information for debugging.
    ///
    /// All error cases conform to `CustomStringConvertible` to provide formatted,
    /// human-readable error messages when tests fail.
    ///
    /// ## Topics
    ///
    /// ### Threshold Violations
    ///
    /// - ``thresholdExceeded(test:metric:expected:actual:)``
    /// - ``performanceExpectationFailed(metric:threshold:actual:)``
    ///
    /// ### Memory Violations
    ///
    /// - ``allocationLimitExceeded(test:limit:actual:)``
    ///
    /// ### Regression Detection
    ///
    /// - ``regressionDetected(metric:baseline:current:regression:tolerance:)``
    public enum Error: Swift.Error, CustomStringConvertible {
        /// Performance threshold was exceeded in a trait-based test.
        ///
        /// Thrown when a test decorated with `.timed(threshold:)` exceeds its performance budget.
        ///
        /// - Parameters:
        ///   - test: Name of the failing test
        ///   - metric: The metric that was checked (e.g., median, p95)
        ///   - expected: The maximum allowed duration
        ///   - actual: The measured duration that exceeded the threshold
        case thresholdExceeded(test: String, metric: Metric, expected: Duration, actual: Duration)

        /// Memory allocation limit was exceeded during test execution.
        ///
        /// Thrown when a test with `maxAllocations` specified allocates more memory
        /// than the configured limit.
        ///
        /// - Parameters:
        ///   - test: Name of the failing test
        ///   - limit: Maximum allowed bytes allocated
        ///   - actual: Actual bytes allocated during the test
        case allocationLimitExceeded(test: String, limit: Int, actual: Int)

        /// Memory leak was detected during test execution.
        ///
        /// Thrown when a test with `.detectLeaks()` trait has net positive allocations
        /// remaining after test completion.
        ///
        /// - Parameters:
        ///   - test: Name of the failing test
        ///   - netAllocations: Number of allocations that were not deallocated
        ///   - netBytes: Total bytes that were not deallocated
        case memoryLeakDetected(test: String, netAllocations: Int, netBytes: Int)

        /// Peak memory limit was exceeded during test execution.
        ///
        /// Thrown when a test with `.trackPeakMemory(limit:)` exceeds the specified
        /// peak memory budget.
        ///
        /// - Parameters:
        ///   - test: Name of the failing test
        ///   - limit: Maximum allowed peak memory in bytes
        ///   - actual: Actual peak memory usage in bytes
        case peakMemoryExceeded(test: String, limit: Int, actual: Int)

        /// Performance expectation assertion failed.
        ///
        /// Thrown by ``TestingPerformance/expectPerformance(lessThan:warmup:iterations:metric:operation:)-5llun``
        /// when the measured performance exceeds the specified threshold.
        ///
        /// - Parameters:
        ///   - metric: The metric that was checked
        ///   - threshold: The maximum allowed duration
        ///   - actual: The measured duration that exceeded the threshold
        case performanceExpectationFailed(metric: Metric, threshold: Duration, actual: Duration)

        /// Performance regression was detected when comparing to a baseline.
        ///
        /// Thrown by ``TestingPerformance/expectNoRegression(current:baseline:tolerance:metric:)``
        /// when current performance has regressed beyond the allowed tolerance.
        ///
        /// - Parameters:
        ///   - metric: The metric that was compared
        ///   - baseline: The baseline (historical) duration
        ///   - current: The current (measured) duration
        ///   - regression: The regression as a fraction (e.g., 0.15 = 15% slower)
        ///   - tolerance: The maximum allowed regression fraction
        case regressionDetected(
            metric: Metric,
            baseline: Duration,
            current: Duration,
            regression: Double,
            tolerance: Double
        )

        public var description: String {
            switch self {
            case .thresholdExceeded(let test, let metric, let expected, let actual):
                return """
                    Performance threshold exceeded in '\(test)':
                    Expected \(metric): < \(TestingPerformance.formatDuration(expected))
                    Actual \(metric): \(TestingPerformance.formatDuration(actual))
                    """

            case .allocationLimitExceeded(let test, let limit, let actual):
                return """
                    Memory allocation limit exceeded in '\(test)':
                    Limit: \(formatBytes(limit))
                    Actual: \(formatBytes(actual))
                    Exceeded by: \(formatBytes(actual - limit))
                    """

            case .memoryLeakDetected(let test, let netAllocations, let netBytes):
                return """
                    Memory leak detected in '\(test)':
                    Net allocations: \(netAllocations)
                    Net bytes: \(formatBytes(netBytes))
                    """

            case .peakMemoryExceeded(let test, let limit, let actual):
                return """
                    Peak memory limit exceeded in '\(test)':
                    Limit: \(formatBytes(limit))
                    Actual peak: \(formatBytes(actual))
                    Exceeded by: \(formatBytes(actual - limit))
                    """

            case .performanceExpectationFailed(let metric, let threshold, let actual):
                return """
                    Performance expectation failed:
                    Expected \(metric) < \(TestingPerformance.formatDuration(threshold))
                    Actual: \(TestingPerformance.formatDuration(actual))
                    Exceeded by: \(TestingPerformance.formatDuration(actual - threshold))
                    """

            case .regressionDetected(
                let metric,
                let baseline,
                let current,
                let regression,
                let tolerance
            ):
                return """
                    Performance regression detected:
                    Baseline \(metric): \(TestingPerformance.formatDuration(baseline))
                    Current \(metric): \(TestingPerformance.formatDuration(current))
                    Regression: \(formatPercent(regression * 100))%
                    Tolerance: \(formatPercent(tolerance * 100))%
                    """
            }
        }

        private func formatBytes(_ bytes: Int) -> String {
            if bytes == 0 {
                return "0 bytes"
            } else if bytes < 1024 {
                return "\(bytes) bytes"
            } else if bytes < 1024 * 1024 {
                return formatNumber(Double(bytes) / 1024.0, decimals: 2) + " KB"
            } else if bytes < 1024 * 1024 * 1024 {
                return formatNumber(Double(bytes) / (1024.0 * 1024.0), decimals: 2) + " MB"
            } else {
                return formatNumber(Double(bytes) / (1024.0 * 1024.0 * 1024.0), decimals: 2) + " GB"
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

            let doubleFraction: Double = fractionalPart * multiplier
            var fractionStr = "\(Int(doubleFraction.rounded()))"
            while fractionStr.count < decimals {
                fractionStr = "0" + fractionStr
            }

            return "\(integerPart).\(fractionStr)"
        }

        private func formatPercent(_ value: Double) -> String {
            let multiplier = 10.0
            let rounded = (value * multiplier).rounded() / multiplier

            let integerPart = Int(rounded)
            let fractionalPart = rounded - Double(integerPart)

            if fractionalPart == 0 {
                return "\(integerPart).0"
            }

            let fractionStr = "\(Int((fractionalPart * multiplier).rounded()))"
            return "\(integerPart).\(fractionStr)"
        }
    }
}
