// Assertions.swift
// TestingPerformance
//
// Performance threshold assertions for Swift Testing

extension TestingPerformance {
    /// Assert that an operation completes within a duration threshold
    ///
    /// Example:
    /// ```swift
    /// try TestingPerformance.expectPerformance(lessThan: .milliseconds(100)) {
    ///     numbers.sum()
    /// }
    /// ```
    @discardableResult
    public static func expectPerformance<T>(
        lessThan threshold: Duration,
        warmup: Int = 0,
        iterations: Int = 10,
        metric: TestingPerformance.Metric = .median,
        operation: () -> T
    ) throws(TestingPerformance.Error) -> (result: T, measurement: TestingPerformance.Measurement) {
        let (result, measurement) = measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )

        let actualDuration = metric.extract(from: measurement)

        guard actualDuration <= threshold else {
            throw TestingPerformance.Error.performanceExpectationFailed(
                metric: metric,
                threshold: threshold,
                actual: actualDuration
            )
        }

        return (result, measurement)
    }

    /// Assert that an async operation completes within a duration threshold
    @discardableResult
    public static func expectPerformance<T>(
        lessThan threshold: Duration,
        warmup: Int = 0,
        iterations: Int = 10,
        metric: TestingPerformance.Metric = .median,
        operation: () async throws -> T
    ) async throws -> (result: T, measurement: TestingPerformance.Measurement) {
        let (result, measurement) = try await measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )

        let actualDuration = metric.extract(from: measurement)

        guard actualDuration <= threshold else {
            throw TestingPerformance.Error.performanceExpectationFailed(
                metric: metric,
                threshold: threshold,
                actual: actualDuration
            )
        }

        return (result, measurement)
    }
}

extension TestingPerformance {
    /// Performance metrics that can be asserted against
    public enum Metric: String, Sendable {
        case min
        case max
        case median
        case mean
        case p95
        case p99

        public func extract(from measurement: Measurement) -> Duration {
            switch self {
            case .min: return measurement.min
            case .max: return measurement.max
            case .median: return measurement.median
            case .mean: return measurement.mean
            case .p95: return measurement.p95
            case .p99: return measurement.p99
            }
        }
    }
}

extension TestingPerformance {
    /// Performance regression detector
    ///
    /// Compares current performance against a baseline with tolerance.
    ///
    /// Example:
    /// ```swift
    /// let baseline = PerformanceMeasurement(durations: [.milliseconds(10)])
    /// let (result, measurement) = TestingPerformance.measure { operation() }
    ///
    /// TestingPerformance.expectNoRegression(
    ///     current: measurement,
    ///     baseline: baseline,
    ///     tolerance: 0.10  // 10% regression allowed
    /// )
    /// ```
    public static func expectNoRegression(
        current: TestingPerformance.Measurement,
        baseline: TestingPerformance.Measurement,
        tolerance: Double = 0.10,
        metric: TestingPerformance.Metric = .median
    ) throws(TestingPerformance.Error) {
        let currentValue = metric.extract(from: current)
        let baselineValue = metric.extract(from: baseline)

        let regression =
            (currentValue.inSeconds - baselineValue.inSeconds) / baselineValue.inSeconds

        guard regression <= tolerance else {
            throw TestingPerformance.Error.regressionDetected(
                metric: metric,
                baseline: baselineValue,
                current: currentValue,
                regression: regression,
                tolerance: tolerance
            )
        }
    }

    private static func formatPercent(_ value: Double) -> String {
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
