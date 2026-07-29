// PerformanceComparisonTests.swift
// TestingPerformance
//
// PerformanceComparison tests

import Testing
import TestingPerformance

extension PerformanceTests {
    @Suite(.serialized)
    struct PerformanceComparisonTests {

        @Test
        func `performance comparison regression detection`() {
            let baseline = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(10), count: 10)
            )

            let slower = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(15), count: 10)
            )

            let comparison = PerformanceComparison(
                name: "Operation",
                current: slower,
                baseline: baseline
            )

            #expect(comparison.isRegression)
            #expect(!comparison.isImprovement)
            #expect(comparison.change > 0)
        }

        @Test
        func `performance comparison improvement detection`() {
            let baseline = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(10), count: 10)
            )

            let faster = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(8), count: 10)
            )

            let comparison = PerformanceComparison(
                name: "Operation",
                current: faster,
                baseline: baseline
            )

            #expect(!comparison.isRegression)
            #expect(comparison.isImprovement)
            #expect(comparison.change < 0)
        }

        @Test
        func `performance comparison report`() {
            let baseline1 = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(10), count: 10)
            )

            let current1 = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(8), count: 10)
            )

            let baseline2 = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(5), count: 10)
            )

            let current2 = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(6), count: 10)
            )

            let comparisons = [
                PerformanceComparison(name: "Operation A", current: current1, baseline: baseline1),
                PerformanceComparison(name: "Operation B", current: current2, baseline: baseline2)
            ]

            // Print report (for manual inspection)
            TestingPerformance.printComparisonReport(comparisons)

            #expect(comparisons[0].isImprovement)
            #expect(comparisons[1].isRegression)
        }

        @Test
        func `performance comparison formatted output`() {
            let baseline = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(10), count: 10)
            )

            let current = TestingPerformance.Measurement(
                durations: Array(repeating: .milliseconds(12), count: 10)
            )

            let comparison = PerformanceComparison(
                name: "Test Operation",
                current: current,
                baseline: baseline
            )

            let formatted = comparison.formatted()
            #expect(formatted.contains("Test Operation"))
            #expect(formatted.contains("Baseline"))
            #expect(formatted.contains("Current"))
            #expect(formatted.contains("Change"))
        }
    }
}
