// Codable Tests.swift
// TestingPerformance

import Foundation
import Testing
import TestingPerformance

extension PerformanceTests {
    @Test("Codable - encode and decode measurement")
    func codableEncodeDecode() throws {
        let original = TestingPerformance.Measurement(durations: [
            .milliseconds(10),
            .milliseconds(20),
            .milliseconds(30)
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestingPerformance.Measurement.self, from: data)

        #expect(decoded.durations.count == original.durations.count)
        #expect(decoded.median == original.median)
        #expect(decoded.mean == original.mean)
        #expect(decoded.min == original.min)
        #expect(decoded.max == original.max)
    }

    @Test("Codable - empty durations")
    func codableEmptyDurations() throws {
        let original = TestingPerformance.Measurement(durations: [])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestingPerformance.Measurement.self, from: data)

        #expect(decoded.durations.isEmpty)
    }

    @Test("Codable - single duration")
    func codableSingleDuration() throws {
        let original = TestingPerformance.Measurement(durations: [.milliseconds(42)])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestingPerformance.Measurement.self, from: data)

        #expect(decoded.durations.count == 1)
        #expect(decoded.median == .milliseconds(42))
    }

    @Test("Codable - large dataset")
    func codableLargeDataset() throws {
        let durations = (1...1000).map { Duration.milliseconds($0) }
        let original = TestingPerformance.Measurement(durations: durations)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestingPerformance.Measurement.self, from: data)

        #expect(decoded.durations.count == 1000)
        #expect(decoded.median == original.median)
        #expect(decoded.p95 == original.p95)
    }

    @Test("Codable - preserves duration precision")
    func codablePreservesPrecision() throws {
        let original = TestingPerformance.Measurement(durations: [
            .nanoseconds(123),
            .microseconds(456),
            .milliseconds(789),
            .seconds(1)
        ])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestingPerformance.Measurement.self, from: data)

        #expect(decoded.durations.count == 4)

        // Check each duration is preserved
        for (idx, duration) in original.durations.enumerated() {
            #expect(decoded.durations[idx] == duration)
        }
    }

    @Test("Codable - pretty printed JSON")
    func codablePrettyPrint() throws {
        let measurement = TestingPerformance.Measurement(durations: [
            .milliseconds(10),
            .milliseconds(20)
        ])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(measurement)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        #expect(json!.contains("durations"))
    }

    @Test("Codable - array of measurements")
    func codableArrayOfMeasurements() throws {
        let measurements = [
            TestingPerformance.Measurement(durations: [.milliseconds(10)]),
            TestingPerformance.Measurement(durations: [.milliseconds(20)]),
            TestingPerformance.Measurement(durations: [.milliseconds(30)])
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(measurements)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([TestingPerformance.Measurement].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].median == .milliseconds(10))
        #expect(decoded[1].median == .milliseconds(20))
        #expect(decoded[2].median == .milliseconds(30))
    }

    @Test("Codable - measurement in dictionary")
    func codableDictionary() throws {
        let measurements: [String: TestingPerformance.Measurement] = [
            "fast": TestingPerformance.Measurement(durations: [.milliseconds(10)]),
            "slow": TestingPerformance.Measurement(durations: [.milliseconds(100)])
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(measurements)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: TestingPerformance.Measurement].self, from: data)

        #expect(decoded.count == 2)
        #expect(decoded["fast"]?.median == .milliseconds(10))
        #expect(decoded["slow"]?.median == .milliseconds(100))
    }
}
