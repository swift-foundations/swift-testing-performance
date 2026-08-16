// Reporting.swift
// TestingPerformance
//
// Performance test reporting and formatting

import Real_Primitives

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import CRT
#endif

extension TestingPerformance {
    /// Print a performance measurement summary
    ///
    /// Example:
    /// ```swift
    /// let measurement = TestingPerformance.measure(iterations: 100) { operation() }
    /// TestingPerformance.printPerformance("Operation Name", measurement)
    /// ```
    public static func printPerformance(
        _ name: String,
        _ measurement: TestingPerformance.Measurement,
        allocations: [Int]? = nil,
        peakMemory: Int? = nil
    ) {
        var output = """
            ⏱️ \(name)
               Iterations: \(measurement.durations.count)
               Min:        \(formatDuration(measurement.min))
               Median:     \(formatDuration(measurement.median))
               Mean:       \(formatDuration(measurement.mean))
               p95:        \(formatDuration(measurement.p95))
               p99:        \(formatDuration(measurement.p99))
               Max:        \(formatDuration(measurement.max))
               StdDev:     \(formatDuration(measurement.standardDeviation))
            """

        if let allocations, !allocations.isEmpty {
            let minAlloc = allocations.min() ?? 0
            let maxAlloc = allocations.max() ?? 0
            let avgAlloc = allocations.reduce(0, +) / allocations.count

            output += """

                   Allocations:
                     Min:      \(formatBytes(minAlloc))
                     Median:   \(formatBytes(allocations.sorted()[allocations.count / 2]))
                     Max:      \(formatBytes(maxAlloc))
                     Avg:      \(formatBytes(avgAlloc))
                """
        }

        if let peak = peakMemory {
            output += """

                   Peak Memory: \(formatBytes(peak))
                """
        }

        print(output)
    }

    private static func formatBytes(_ bytes: Int) -> String {
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

    private static func formatNumber(_ value: Double, decimals: Int) -> String {
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

// MARK: - ANSI Color Support

extension TestingPerformance {
    /// ANSI color codes for terminal output
    internal enum ANSIColor: String {
        case reset = "\u{001B}[0m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case bold = "\u{001B}[1m"
        case dim = "\u{001B}[2m"

        /// Check if terminal supports ANSI colors
        static var isSupported: Bool {
            #if os(Linux) || os(macOS)
                // Check TERM environment variable using C getenv
                guard let termPtr = getenv("TERM") else {
                    return false
                }
                let term = String(cString: termPtr)
                // Most modern terminals support colors
                return term != "dumb" && !term.isEmpty
            #else
                return false
            #endif
        }

        /// Wrap text in color if supported
        static func colored(_ text: String, color: ANSIColor) -> String {
            guard isSupported else { return text }
            return color.rawValue + text + ANSIColor.reset.rawValue
        }
    }

    /// Center text within a given width
    internal static func centerText(_ text: String, width: Int) -> String {
        let padding = width - text.count
        guard padding > 0 else { return text }

        let leftPad = padding / 2
        let rightPad = padding - leftPad

        return String(repeating: " ", count: leftPad) + text
            + String(repeating: " ", count: rightPad)
    }
}

/// Performance comparison report
public struct PerformanceComparison: Sendable {
    public let name: String
    public let current: TestingPerformance.Measurement
    public let baseline: TestingPerformance.Measurement
    public let metric: TestingPerformance.Metric

    public init(
        name: String,
        current: TestingPerformance.Measurement,
        baseline: TestingPerformance.Measurement,
        metric: TestingPerformance.Metric = .median
    ) {
        self.name = name
        self.current = current
        self.baseline = baseline
        self.metric = metric
    }

    public var currentValue: Duration {
        metric.extract(from: current)
    }

    public var baselineValue: Duration {
        metric.extract(from: baseline)
    }

    public var change: Double {
        (currentValue.inSeconds - baselineValue.inSeconds) / baselineValue.inSeconds
    }

    public var isRegression: Bool {
        change > 0
    }

    public var isImprovement: Bool {
        change < 0
    }

    public func formatted() -> String {
        let changePercent = abs(change) * 100
        let changeSymbol = isRegression ? "↑" : "↓"
        let changeEmoji = isRegression ? "🔴" : "🟢"

        // Apply ANSI color if supported
        let nameColored =
            isRegression
            ? TestingPerformance.ANSIColor.colored(name, color: .red)
            : TestingPerformance.ANSIColor.colored(name, color: .green)

        let changeText = "\(changeSymbol) \(formatPercent(changePercent))%"
        let changeColored =
            isRegression
            ? TestingPerformance.ANSIColor.colored(changeText, color: .red)
            : TestingPerformance.ANSIColor.colored(changeText, color: .green)

        return """
            \(changeEmoji) \(nameColored)
                Baseline: \(TestingPerformance.formatDuration(baselineValue))
                Current:  \(TestingPerformance.formatDuration(currentValue))
                Change:   \(changeColored)
            """
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

extension TestingPerformance {
    /// Print comparison report for multiple benchmarks
    public static func printComparisonReport(_ comparisons: [PerformanceComparison]) {
        let boxWidth = 58  // Inner width of the box (excluding borders)
        let title = "PERFORMANCE COMPARISON REPORT"
        let centeredTitle = centerText(title, width: boxWidth)

        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║\(centeredTitle)║")
        print("╚══════════════════════════════════════════════════════════╝\n")

        for comparison in comparisons {
            print(comparison.formatted())
            print("")
        }

        let regressions = comparisons.filter { $0.isRegression }.count
        let improvements = comparisons.filter { $0.isImprovement }.count
        let neutral = comparisons.count - regressions - improvements

        // Make summary more prominent
        let summaryText =
            "Summary: \(improvements) improvements, \(neutral) neutral, \(regressions) regressions"
        let summaryColored = ANSIColor.colored(summaryText, color: .bold)
        print(summaryColored)
        print("╚══════════════════════════════════════════════════════════╝\n")
    }
}

/// Performance benchmark suite
///
/// Collects and reports on multiple related benchmarks.
///
/// Example:
/// ```swift
/// var suite = PerformanceSuite(name: "Sequence Operations")
///
/// suite.benchmark("sum") {
///     numbers.sum()
/// }
///
/// suite.benchmark("product") {
///     numbers.product()
/// }
///
/// suite.printReport()
/// ```
public struct PerformanceSuite {
    /// Name of the performance suite for reporting.
    public let name: String
    private var benchmarks: [(name: String, measurement: TestingPerformance.Measurement)] = []

    /// Creates a new performance suite with the given name.
    ///
    /// - Parameter name: Display name for the suite in reports
    public init(name: String) {
        self.name = name
    }

    /// Run and measure a synchronous benchmark operation.
    ///
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - warmup: Number of warmup iterations (default: 0)
    ///   - iterations: Number of measured iterations (default: 10)
    ///   - operation: The operation to benchmark
    /// - Returns: The result of the operation
    public mutating func benchmark<T>(
        _ name: String,
        warmup: Int = 0,
        iterations: Int = 10,
        operation: () -> T
    ) -> T {
        let (result, measurement) = TestingPerformance.measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )
        benchmarks.append((name, measurement))
        return result
    }

    /// Run and measure an asynchronous benchmark operation.
    ///
    /// - Parameters:
    ///   - name: Name of the benchmark
    ///   - warmup: Number of warmup iterations (default: 0)
    ///   - iterations: Number of measured iterations (default: 10)
    ///   - operation: The async operation to benchmark
    /// - Returns: The result of the operation
    public mutating func benchmark<T>(
        _ name: String,
        warmup: Int = 0,
        iterations: Int = 10,
        operation: () async throws -> T
    ) async rethrows -> T {
        let (result, measurement) = try await TestingPerformance.measure(
            warmup: warmup,
            iterations: iterations,
            operation: operation
        )
        benchmarks.append((name, measurement))
        return result
    }

    /// Print a formatted report of all benchmarks in the suite.
    ///
    /// - Parameter metric: The metric to display for each benchmark (default: median)
    public func printReport(metric: TestingPerformance.Metric = .median) {
        let boxWidth = 58  // Inner width of the box (excluding borders)
        let centeredTitle = TestingPerformance.centerText(name, width: boxWidth)

        print("\n╔══════════════════════════════════════════════════════════╗")
        print("║\(centeredTitle)║")
        print("╚══════════════════════════════════════════════════════════╝\n")

        let maxNameLength = benchmarks.map { $0.name.count }.max() ?? 0

        for (name, measurement) in benchmarks {
            let value = metric.extract(from: measurement)
            let paddedName = padRight(name, toLength: maxNameLength)
            print("  \(paddedName)  \(TestingPerformance.formatDuration(value))")
        }

        print("\n╚══════════════════════════════════════════════════════════╝\n")
    }

    private func padRight(_ string: String, toLength length: Int) -> String {
        if string.count >= length {
            return string
        }
        return string + String(repeating: " ", count: length - string.count)
    }
}
