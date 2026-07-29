// Statistics.swift
// TestingPerformance
//
// Statistical significance testing

import Real_Primitives

extension TestingPerformance.Measurement {

    /// Test if this measurement is significantly different from another
    ///
    /// Uses Welch's t-test to determine if the difference between two measurements
    /// is statistically significant.
    ///
    /// - Parameters:
    ///   - other: The measurement to compare against
    ///   - confidenceLevel: The confidence level (default: 0.95 for 95% confidence)
    /// - Returns: `true` if the measurements are significantly different
    ///
    /// Example:
    /// ```swift
    /// let before = TestingPerformance.measure { oldAlgorithm() }.measurement
    /// let after = TestingPerformance.measure { newAlgorithm() }.measurement
    ///
    /// if after.isSignificantlyDifferent(from: before, confidenceLevel: 0.95) {
    ///     print("Performance change is statistically significant")
    /// }
    /// ```
    public func isSignificantlyDifferent(
        from other: TestingPerformance.Measurement,
        confidenceLevel: Double = 0.95
    ) -> Bool {
        // Welch's t-test for two samples with potentially different variances

        guard !durations.isEmpty && !other.durations.isEmpty else {
            return false
        }

        // Sample sizes
        let n1 = Double(durations.count)
        let n2 = Double(other.durations.count)

        // Means
        let mean1 = mean.inSeconds
        let mean2 = other.mean.inSeconds

        // Variances
        let var1 = variance
        let var2 = other.variance

        // Welch's t-statistic
        let numerator = mean1 - mean2
        let denominator = ((var1 / n1) + (var2 / n2)).squareRoot()

        guard denominator > 0 else {
            // Special case: zero variance means all samples are identical
            // If means differ and both have zero variance, difference is significant
            return abs(mean1 - mean2) > 0
        }

        let tStatistic = abs(numerator / denominator)

        // Welch-Satterthwaite degrees of freedom
        let sumOfVarianceRatios = (var1 / n1) + (var2 / n2)
        let numeratorDF = sumOfVarianceRatios * sumOfVarianceRatios
        let var1Ratio = var1 / n1
        let var2Ratio = var2 / n2
        let denominatorDF = (var1Ratio * var1Ratio / (n1 - 1)) + (var2Ratio * var2Ratio / (n2 - 1))
        let degreesOfFreedom = numeratorDF / denominatorDF

        // Critical value for two-tailed test
        let alpha = 1.0 - confidenceLevel
        let criticalValue = tCritical(df: degreesOfFreedom, alpha: alpha / 2.0)

        return tStatistic > criticalValue
    }

    /// Test if this measurement is significantly faster than another
    ///
    /// Uses one-tailed Welch's t-test.
    ///
    /// - Parameters:
    ///   - other: The measurement to compare against
    ///   - confidenceLevel: The confidence level (default: 0.95)
    /// - Returns: `true` if this measurement is significantly faster
    public func isSignificantlyFaster(
        than other: TestingPerformance.Measurement,
        confidenceLevel: Double = 0.95
    ) -> Bool {
        guard !durations.isEmpty && !other.durations.isEmpty else {
            return false
        }

        let n1 = Double(durations.count)
        let n2 = Double(other.durations.count)

        let mean1 = mean.inSeconds
        let mean2 = other.mean.inSeconds

        // Check direction: we want mean1 < mean2 (faster)
        guard mean1 < mean2 else {
            return false
        }

        let var1 = variance
        let var2 = other.variance

        let numerator = mean1 - mean2
        let denominator = ((var1 / n1) + (var2 / n2)).squareRoot()

        guard denominator > 0 else {
            // Special case: zero variance means all samples are identical
            // If means differ and both have zero variance, difference is significant
            return abs(mean1 - mean2) > 0
        }

        let tStatistic = numerator / denominator  // Negative because mean1 < mean2

        let sumOfVarianceRatios2 = (var1 / n1) + (var2 / n2)
        let numeratorDF = sumOfVarianceRatios2 * sumOfVarianceRatios2
        let var1Ratio2 = var1 / n1
        let var2Ratio2 = var2 / n2
        let denominatorDF =
            (var1Ratio2 * var1Ratio2 / (n1 - 1)) + (var2Ratio2 * var2Ratio2 / (n2 - 1))
        let degreesOfFreedom = numeratorDF / denominatorDF

        let alpha = 1.0 - confidenceLevel
        let criticalValue = -tCritical(df: degreesOfFreedom, alpha: alpha)

        return tStatistic < criticalValue
    }

    /// Test if this measurement is significantly slower than another
    ///
    /// Uses one-tailed Welch's t-test.
    ///
    /// - Parameters:
    ///   - other: The measurement to compare against
    ///   - confidenceLevel: The confidence level (default: 0.95)
    /// - Returns: `true` if this measurement is significantly slower
    public func isSignificantlySlower(
        than other: TestingPerformance.Measurement,
        confidenceLevel: Double = 0.95
    ) -> Bool {
        other.isSignificantlyFaster(than: self, confidenceLevel: confidenceLevel)
    }

    /// Variance of the sample
    private var variance: Double {
        guard durations.count > 1 else { return 0 }

        let meanSeconds = mean.inSeconds
        let sumSquaredDiff = durations.reduce(0.0) { acc, duration in
            let diff = duration.inSeconds - meanSeconds
            return acc + (diff * diff)
        }

        return sumSquaredDiff / Double(durations.count - 1)
    }

    /// Approximate t-distribution critical value
    ///
    /// Uses approximation for common confidence levels, falls back to normal distribution
    /// for very large degrees of freedom.
    private func tCritical(df: Double, alpha: Double) -> Double {
        // For very large df (>100), t-distribution approaches normal distribution
        if df > 100 {
            return Self.zScore(alpha: alpha)
        }

        // Approximation for smaller df using lookup table
        // Common values for two-tailed 95% confidence (alpha = 0.025)
        if alpha <= 0.03 && alpha >= 0.02 {
            return Self.tValue95Confidence(df: df)
        }

        // Fallback: use normal approximation
        return 1.96
    }

    /// Z-scores for common alpha values (two-tailed)
    private static func zScore(alpha: Double) -> Double {
        switch alpha {
        case ...0.001: return 3.291  // 99.9% confidence
        case ...0.01: return 2.576  // 99% confidence
        case ...0.025: return 1.96  // 95% confidence
        case ...0.05: return 1.645  // 90% confidence
        default: return 1.282  // 80% confidence
        }
    }

    /// T-distribution critical values for 95% confidence (alpha = 0.025)
    private static func tValue95Confidence(df: Double) -> Double {
        switch df {
        case ..<2: return 12.706
        case ..<3: return 4.303
        case ..<4: return 3.182
        case ..<5: return 2.776
        case ..<6: return 2.571
        case ..<7: return 2.447
        case ..<8: return 2.365
        case ..<9: return 2.306
        case ..<10: return 2.262
        case ..<15: return 2.145
        case ..<20: return 2.093
        case ..<30: return 2.042
        case ..<40: return 2.021
        case ..<60: return 2.000
        default: return 1.980
        }
    }
}
