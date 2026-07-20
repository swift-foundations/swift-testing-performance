// _PerformanceTraitTests.swift
// TestingPerformance
//
// Regression tests for combined performance trait composition (fable-448 F-001)

import Synchronization
import Testing
import TestingPerformance

extension _PerformanceTrait {
    @Suite
    struct Unit {
        @Test
        func `combining timed and detectLeaks runs exactly one measurement loop`() async throws {
            let outer = _PerformanceTrait.timed(
                iterations: 3,
                warmup: 0,
                trackAllocations: false
            )
            let inner = _PerformanceTrait.detectLeaks()
            let executions = Atomic<Int>(0)
            let test = try #require(Test.current)

            try await outer.provideScope(for: test, testCase: nil) {
                try await inner.provideScope(for: test, testCase: nil) {
                    executions.add(1, ordering: .relaxed)
                }
            }

            // Exactly the outer trait's 3 iterations — the inner trait must
            // contribute configuration only, not start a second nested loop.
            #expect(executions.load(ordering: .relaxed) == 3)
        }

        @Test
        func `inner trait defaults do not clobber outer explicit iteration and warmup counts`()
            async throws
        {
            let outer = _PerformanceTrait.timed(
                iterations: 2,
                warmup: 1,
                trackAllocations: false
            )
            let inner = _PerformanceTrait.trackPeakMemory()
            let executions = Atomic<Int>(0)
            let test = try #require(Test.current)

            try await outer.provideScope(for: test, testCase: nil) {
                try await inner.provideScope(for: test, testCase: nil) {
                    executions.add(1, ordering: .relaxed)
                }
            }

            // 1 warmup + 2 measured iterations = 3 total body executions.
            #expect(executions.load(ordering: .relaxed) == 3)
        }
    }
}
