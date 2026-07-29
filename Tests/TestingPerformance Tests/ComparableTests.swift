// Comparable Tests.swift
// TestingPerformance

import Testing
import TestingPerformance

extension PerformanceTests {
    @Test("Measurement Comparable - equal measurements")
    func comparableEqual() {
        let m1 = TestingPerformance.Measurement(durations: [
            .milliseconds(10), .milliseconds(20), .milliseconds(30)
        ])
        let m2 = TestingPerformance.Measurement(durations: [
            .milliseconds(10), .milliseconds(20), .milliseconds(30)
        ])

        #expect(m1 == m2)
        #expect(!(m1 < m2))
        #expect(!(m1 > m2))
        #expect(m1 <= m2)
        #expect(m1 >= m2)
    }

    @Test("Measurement Comparable - less than")
    func comparableLessThan() {
        let faster = TestingPerformance.Measurement(durations: [
            .milliseconds(5), .milliseconds(10), .milliseconds(15)
        ])
        let slower = TestingPerformance.Measurement(durations: [
            .milliseconds(20), .milliseconds(30), .milliseconds(40)
        ])

        #expect(faster < slower)
        #expect(!(slower < faster))
        #expect(faster != slower)
    }

    @Test("Measurement Comparable - greater than")
    func comparableGreaterThan() {
        let faster = TestingPerformance.Measurement(durations: [
            .milliseconds(5), .milliseconds(10), .milliseconds(15)
        ])
        let slower = TestingPerformance.Measurement(durations: [
            .milliseconds(20), .milliseconds(30), .milliseconds(40)
        ])

        #expect(slower > faster)
        #expect(!(faster > slower))
    }

    @Test("Measurement Comparable - sorting")
    func comparableSorting() {
        let measurements = [
            TestingPerformance.Measurement(durations: [.milliseconds(30)]),
            TestingPerformance.Measurement(durations: [.milliseconds(10)]),
            TestingPerformance.Measurement(durations: [.milliseconds(20)])
        ]

        let sorted = measurements.sorted()

        #expect(sorted[0].median == .milliseconds(10))
        #expect(sorted[1].median == .milliseconds(20))
        #expect(sorted[2].median == .milliseconds(30))
    }

    @Test("Measurement Comparable - min/max")
    func comparableMinMax() {
        let measurements = [
            TestingPerformance.Measurement(durations: [.milliseconds(30)]),
            TestingPerformance.Measurement(durations: [.milliseconds(10)]),
            TestingPerformance.Measurement(durations: [.milliseconds(20)])
        ]

        let fastest = measurements.min()
        let slowest = measurements.max()

        #expect(fastest?.median == .milliseconds(10))
        #expect(slowest?.median == .milliseconds(30))
    }

    @Test("Measurement Comparable - compares by median")
    func comparableUseMedian() {
        // Different distributions but same median
        let m1 = TestingPerformance.Measurement(durations: [
            .milliseconds(5), .milliseconds(20), .milliseconds(100)
        ])
        let m2 = TestingPerformance.Measurement(durations: [
            .milliseconds(10), .milliseconds(20), .milliseconds(50)
        ])

        #expect(m1 == m2)  // Both have median of 20ms
    }
}
