// Statistics Tests.swift
// TestingPerformance

import Testing
import TestingPerformance

extension PerformanceTests {
    @Test("Statistics - significantly different measurements")
    func statisticsSignificantlyDifferent() {
        // Two measurements with clearly different means
        let fast = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 30)
        )
        let slow = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(100), count: 30)
        )

        #expect(fast.isSignificantlyDifferent(from: slow, confidenceLevel: 0.95))
        #expect(slow.isSignificantlyDifferent(from: fast, confidenceLevel: 0.95))
    }

    @Test("Statistics - not significantly different measurements")
    func statisticsNotSignificantlyDifferent() {
        // Two measurements with similar distributions
        let m1 = TestingPerformance.Measurement(durations: [
            .milliseconds(9), .milliseconds(10), .milliseconds(11),
            .milliseconds(10), .milliseconds(10), .milliseconds(10)
        ])
        let m2 = TestingPerformance.Measurement(durations: [
            .milliseconds(9), .milliseconds(10), .milliseconds(11),
            .milliseconds(10), .milliseconds(10), .milliseconds(10)
        ])

        #expect(!m1.isSignificantlyDifferent(from: m2, confidenceLevel: 0.95))
    }

    @Test("Statistics - significantly faster")
    func statisticsSignificantlyFaster() {
        let fast = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 30)
        )
        let slow = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(100), count: 30)
        )

        #expect(fast.isSignificantlyFaster(than: slow, confidenceLevel: 0.95))
        #expect(!slow.isSignificantlyFaster(than: fast, confidenceLevel: 0.95))
    }

    @Test("Statistics - not significantly faster when actually slower")
    func statisticsNotFasterWhenSlower() {
        let fast = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 30)
        )
        let slow = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(100), count: 30)
        )

        #expect(!slow.isSignificantlyFaster(than: fast, confidenceLevel: 0.95))
    }

    @Test("Statistics - significantly slower")
    func statisticsSignificantlySlower() {
        let fast = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 30)
        )
        let slow = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(100), count: 30)
        )

        #expect(slow.isSignificantlySlower(than: fast, confidenceLevel: 0.95))
        #expect(!fast.isSignificantlySlower(than: slow, confidenceLevel: 0.95))
    }

    @Test("Statistics - empty measurements not significant")
    func statisticsEmptyMeasurements() {
        let empty = TestingPerformance.Measurement(durations: [])
        let full = TestingPerformance.Measurement(durations: [.milliseconds(10)])

        #expect(!empty.isSignificantlyDifferent(from: full))
        #expect(!full.isSignificantlyDifferent(from: empty))
        #expect(!empty.isSignificantlyFaster(than: full))
        #expect(!empty.isSignificantlySlower(than: full))
    }

    @Test("Statistics - identical measurements not significant")
    func statisticsIdenticalMeasurements() {
        let m1 = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 10)
        )
        let m2 = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 10)
        )

        #expect(!m1.isSignificantlyDifferent(from: m2))
        #expect(!m1.isSignificantlyFaster(than: m2))
        #expect(!m1.isSignificantlySlower(than: m2))
    }

    @Test("Statistics - different confidence levels")
    func statisticsDifferentConfidenceLevels() {
        // Measurements with moderate difference
        let m1 = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 20)
        )
        let m2 = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(15), count: 20)
        )

        // At 90% confidence (less strict)
        let at90 = m1.isSignificantlyDifferent(from: m2, confidenceLevel: 0.90)

        // At 99% confidence (more strict)
        let at99 = m1.isSignificantlyDifferent(from: m2, confidenceLevel: 0.99)

        // More lenient threshold should be more likely to detect difference
        if at99 {
            #expect(at90)  // If significant at 99%, must be significant at 90%
        }
    }

    @Test("Statistics - small sample sizes")
    func statisticsSmallSamples() {
        let m1 = TestingPerformance.Measurement(durations: [.milliseconds(5), .milliseconds(10)])
        let m2 = TestingPerformance.Measurement(durations: [.milliseconds(100), .milliseconds(105)])

        // Should still detect very large differences even with small samples
        #expect(m1.isSignificantlyDifferent(from: m2, confidenceLevel: 0.95))
    }

    @Test("Statistics - variance matters")
    func statisticsVarianceMatters() {
        // Low variance measurements
        let lowVariance = TestingPerformance.Measurement(durations: [
            .milliseconds(99), .milliseconds(100), .milliseconds(101)
        ])

        // High variance measurements with same mean
        let highVariance = TestingPerformance.Measurement(durations: [
            .milliseconds(1), .milliseconds(100), .milliseconds(199)
        ])

        // Both have mean ~100ms, but different variances
        // This test just ensures the variance calculation doesn't crash
        let isDifferent = lowVariance.isSignificantlyDifferent(from: highVariance)

        // Test passes as long as we get a result (true or false)
        _ = isDifferent
    }

    @Test("Statistics - reflexivity")
    func statisticsReflexivity() {
        let measurement = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 10)
        )

        // A measurement should not be significantly different from itself
        #expect(!measurement.isSignificantlyDifferent(from: measurement))
        #expect(!measurement.isSignificantlyFaster(than: measurement))
        #expect(!measurement.isSignificantlySlower(than: measurement))
    }

    @Test("Statistics - symmetry for different")
    func statisticsSymmetryDifferent() {
        let m1 = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 30)
        )
        let m2 = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(100), count: 30)
        )

        // isSignificantlyDifferent should be symmetric
        let diff1 = m1.isSignificantlyDifferent(from: m2)
        let diff2 = m2.isSignificantlyDifferent(from: m1)

        #expect(diff1 == diff2)
    }

    @Test("Statistics - antisymmetry for faster/slower")
    func statisticsAntisymmetry() {
        let fast = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(10), count: 30)
        )
        let slow = TestingPerformance.Measurement(
            durations: Array(repeating: .milliseconds(100), count: 30)
        )

        // If fast is faster than slow, slow should be slower than fast
        if fast.isSignificantlyFaster(than: slow) {
            #expect(slow.isSignificantlySlower(than: fast))
        }

        if slow.isSignificantlySlower(than: fast) {
            #expect(fast.isSignificantlyFaster(than: slow))
        }
    }
}
