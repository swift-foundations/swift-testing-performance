// MetricsTests.swift
// TestingPerformance
//
// Performance metrics calculation tests

import Testing
import TestingPerformance

extension PerformanceTests {
    @Suite(.serialized)
    struct Metrics {

        @Test
        func `measurement min and max`() {
            let measurement = TestingPerformance.Measurement(
                durations: [
                    .milliseconds(5),
                    .milliseconds(10),
                    .milliseconds(15),
                    .milliseconds(20),
                    .milliseconds(25)
                ]
            )

            #expect(measurement.min == .milliseconds(5))
            #expect(measurement.max == .milliseconds(25))
        }

        @Test
        func `measurement median`() {
            let measurement = TestingPerformance.Measurement(
                durations: [
                    .milliseconds(10),
                    .milliseconds(20),
                    .milliseconds(30),
                    .milliseconds(40),
                    .milliseconds(50)
                ]
            )

            // Median of 5 values is the 3rd value
            #expect(measurement.median == .milliseconds(30))
        }

        @Test
        func `measurement mean`() {
            let measurement = TestingPerformance.Measurement(
                durations: [
                    .milliseconds(10),
                    .milliseconds(20),
                    .milliseconds(30)
                ]
            )

            // Mean = (10 + 20 + 30) / 3 = 20
            let meanMs =
                measurement.mean.components.seconds * 1000 + measurement.mean.components.attoseconds
                / 1_000_000_000_000_000
            #expect(meanMs == 20)
        }

        @Test
        func `measurement percentiles`() {
            let durations = (1...100).map { Duration.milliseconds(Double($0)) }
            let measurement = TestingPerformance.Measurement(durations: durations)

            // p95 should be around the 95th value (close to 95ms)
            #expect(measurement.p95 >= .milliseconds(90))
            #expect(measurement.p95 <= .milliseconds(100))

            // p99 should be around the 99th value (close to 99ms)
            #expect(measurement.p99 >= .milliseconds(95))
            #expect(measurement.p99 <= .milliseconds(100))
        }

        @Test
        func `metric extraction`() {
            let measurement = TestingPerformance.Measurement(
                durations: [
                    .milliseconds(10),
                    .milliseconds(20),
                    .milliseconds(30)
                ]
            )

            #expect(TestingPerformance.Metric.min.extract(from: measurement) == measurement.min)
            #expect(TestingPerformance.Metric.max.extract(from: measurement) == measurement.max)
            #expect(
                TestingPerformance.Metric.median.extract(from: measurement) == measurement.median
            )
            #expect(TestingPerformance.Metric.mean.extract(from: measurement) == measurement.mean)
            #expect(TestingPerformance.Metric.p95.extract(from: measurement) == measurement.p95)
            #expect(TestingPerformance.Metric.p99.extract(from: measurement) == measurement.p99)
        }

        @Test
        func `standard deviation calculation`() {
            let measurement = TestingPerformance.Measurement(
                durations: [
                    .milliseconds(10),
                    .milliseconds(20),
                    .milliseconds(30)
                ]
            )

            // Standard deviation should be > 0 for varying values
            #expect(measurement.standardDeviation > .zero)
        }

        @Test
        func `empty measurement edge case`() {
            let measurement = TestingPerformance.Measurement(durations: [])

            #expect(measurement.min == .zero)
            #expect(measurement.max == .zero)
            #expect(measurement.median == .zero)
            #expect(measurement.mean == .zero)
        }
    }
}
