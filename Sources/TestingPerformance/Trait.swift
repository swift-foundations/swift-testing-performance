// Trait.swift
// TestingPerformance
//
// Performance measurement traits for Swift Testing

#if canImport(Testing)
    @_exported import Testing

    #if compiler(>=6.0)

        @_documentation(visibility: private)
        public struct _PerformanceTrait: TestScoping, TestTrait, SuiteTrait {
            let configuration: TestingPerformance.Configuration
            let sourceLocation: SourceLocation

            @TaskLocal static var currentConfig: TestingPerformance.Configuration?
            @TaskLocal static var currentSourceLocation: SourceLocation?

            public var isRecursive: Bool { true }

            public func provideScope(
                for test: Test,
                testCase: Test.Case?,
                performing function: @Sendable () async throws -> Void
            ) async throws {
                // Merge configurations (parent + current)
                let effectiveConfig =
                    Self.currentConfig?.merged(with: configuration) ?? configuration
                // Use the most recent source location (innermost trait wins)
                let effectiveSourceLocation = sourceLocation

                try await Self.$currentConfig.withValue(effectiveConfig) {
                    try await Self.$currentSourceLocation.withValue(effectiveSourceLocation) {
                        // Run test with performance measurement
                        try await measureTest(
                            name: test.name,
                            config: effectiveConfig,
                            sourceLocation: effectiveSourceLocation,
                            performing: function
                        )
                    }
                }
            }

            private func measureTest(
                name: String,
                config: TestingPerformance.Configuration,
                sourceLocation: SourceLocation,
                performing function: @Sendable () async throws -> Void
            ) async throws {
                guard config.enabled else {
                    try await function()
                    return
                }

                // Initialize leak detector if requested
                let leakDetector: MemoryAllocation.LeakDetector? =
                    config.detectLeaks ? LeakDetector() : nil

                // Initialize peak memory tracker if requested or needed
                let peakTracker: MemoryAllocation.PeakMemoryTracker? =
                    (config.peakMemoryLimit != nil || config.printResults)
                    ? PeakMemoryTracker() : nil

                #if os(Linux)
                    // Start tracking on Linux if we need allocation stats
                    if config.maxAllocations != nil || config.detectLeaks || peakTracker != nil {
                        MemoryAllocation.AllocationStats.startTracking()
                    }
                #endif

                // Warmup
                for _ in 0..<config.warmup {
                    try await function()
                }

                // Measure
                var durations: [Duration] = []
                var allocationDeltas: [Int] = []

                // Determine if we need allocation tracking
                // trackAllocations directly controls whether allocation stats are gathered
                let needsAllocationTracking = config.trackAllocations

                for _ in 0..<config.iterations {
                    if needsAllocationTracking {
                        // Use AllocationTracker.measure() for allocation tracking
                        let result = try await measureWithAllocations(function)
                        durations.append(result.duration)

                        // Track allocation delta if monitoring allocations
                        if config.maxAllocations != nil {
                            allocationDeltas.append(result.stats.bytesAllocated)
                        }
                    } else {
                        // Fast path: just measure duration without allocation tracking overhead
                        let start = ContinuousClock.now
                        try await function()
                        durations.append(ContinuousClock.now - start)
                    }

                    // Sample peak memory if tracking
                    peakTracker?.sample()
                }

                let measurement = TestingPerformance.Measurement(durations: durations)

                // Print and validate results
                let context = ValidationContext(
                    measurement: measurement,
                    allocationDeltas: allocationDeltas,
                    leakDetector: leakDetector,
                    peakTracker: peakTracker
                )
                reportAndValidateResults(
                    name: name,
                    config: config,
                    context: context,
                    sourceLocation: sourceLocation
                )
            }

            private struct ValidationContext {
                let measurement: TestingPerformance.Measurement
                let allocationDeltas: [Int]
                let leakDetector: MemoryAllocation.LeakDetector?
                let peakTracker: MemoryAllocation.PeakMemoryTracker?
            }

            private func reportAndValidateResults(
                name: String,
                config: TestingPerformance.Configuration,
                context: ValidationContext,
                sourceLocation: SourceLocation
            ) {
                // Print if requested
                if config.printResults {
                    let peakBytes = context.peakTracker?.peakBytes
                    TestingPerformance.printPerformance(
                        name,
                        context.measurement,
                        allocations: context.allocationDeltas.isEmpty
                            ? nil : context.allocationDeltas,
                        peakMemory: peakBytes
                    )
                }

                // Validate performance threshold
                validatePerformanceThreshold(
                    name: name,
                    config: config,
                    measurement: context.measurement,
                    sourceLocation: sourceLocation
                )

                // Validate allocation limit
                validateAllocationLimit(
                    name: name,
                    config: config,
                    allocationDeltas: context.allocationDeltas,
                    sourceLocation: sourceLocation
                )

                // Validate no memory leaks
                validateNoMemoryLeaks(
                    name: name,
                    detector: context.leakDetector,
                    sourceLocation: sourceLocation
                )

                // Validate peak memory limit
                validatePeakMemoryLimit(
                    name: name,
                    config: config,
                    tracker: context.peakTracker,
                    sourceLocation: sourceLocation
                )
            }

            private func validatePerformanceThreshold(
                name: String,
                config: TestingPerformance.Configuration,
                measurement: TestingPerformance.Measurement,
                sourceLocation: SourceLocation
            ) {
                guard let error = Self.performanceThresholdError(
                    name: name,
                    config: config,
                    measurement: measurement
                ) else { return }

                Issue.record(
                    Comment(rawValue: error.description),
                    sourceLocation: sourceLocation
                )
            }

            static func performanceThresholdError(
                name: String,
                config: TestingPerformance.Configuration,
                measurement: TestingPerformance.Measurement
            ) -> TestingPerformance.Error? {
                guard let threshold = config.threshold else { return nil }
                let actual = config.metric.extract(from: measurement)
                guard actual > threshold else { return nil }

                return .thresholdExceeded(
                    test: name,
                    metric: config.metric,
                    expected: threshold,
                    actual: actual
                )
            }

            private func validateAllocationLimit(
                name: String,
                config: TestingPerformance.Configuration,
                allocationDeltas: [Int],
                sourceLocation: SourceLocation
            ) {
                guard let maxAllocations = config.maxAllocations, !allocationDeltas.isEmpty else {
                    return
                }

                // Use median instead of max to be robust to parallel test interference
                // On Darwin, malloc_zone_statistics returns process-wide stats
                // In parallel execution, some iterations may capture allocations from other tests
                // Median filters out interference while still catching real allocation issues
                let sortedAllocations = allocationDeltas.sorted()
                let medianIndex = sortedAllocations.count / 2
                let medianAllocationBytes: Int

                if sortedAllocations.count % 2 == 0 {
                    // Even number of samples: average the two middle values
                    medianAllocationBytes =
                        (sortedAllocations[medianIndex - 1] + sortedAllocations[medianIndex]) / 2
                } else {
                    // Odd number of samples: take the middle value
                    medianAllocationBytes = sortedAllocations[medianIndex]
                }

                guard medianAllocationBytes <= maxAllocations else {
                    let error = TestingPerformance.Error.allocationLimitExceeded(
                        test: name,
                        limit: maxAllocations,
                        actual: medianAllocationBytes
                    )
                    Issue.record(
                        Comment(rawValue: error.description),
                        sourceLocation: sourceLocation
                    )
                    return
                }
            }

            private func validateNoMemoryLeaks(
                name: String,
                detector: MemoryAllocation.LeakDetector?,
                sourceLocation: SourceLocation
            ) {
                guard let detector = detector else { return }
                if detector.hasLeaks() {
                    let error = TestingPerformance.Error.memoryLeakDetected(
                        test: name,
                        netAllocations: detector.netAllocations,
                        netBytes: detector.netBytes
                    )
                    Issue.record(
                        Comment(rawValue: error.description),
                        sourceLocation: sourceLocation
                    )
                }
            }

            private func validatePeakMemoryLimit(
                name: String,
                config: TestingPerformance.Configuration,
                tracker: MemoryAllocation.PeakMemoryTracker?,
                sourceLocation: SourceLocation
            ) {
                guard let limit = config.peakMemoryLimit, let tracker = tracker else { return }
                guard tracker.peakBytes <= limit else {
                    let error = TestingPerformance.Error.peakMemoryExceeded(
                        test: name,
                        limit: limit,
                        actual: tracker.peakBytes
                    )
                    Issue.record(
                        Comment(rawValue: error.description),
                        sourceLocation: sourceLocation
                    )
                    return
                }
            }

            // Helper to measure both duration and allocations using AllocationTracker
            private func measureWithAllocations(
                _ function: @Sendable () async throws -> Void
            ) async throws -> MeasurementResult {
                let start = ContinuousClock.now
                let (_, stats) = try await MemoryAllocation.AllocationTracker.measure {
                    try await function()
                }
                let duration = ContinuousClock.now - start
                return MeasurementResult(duration: duration, stats: stats)
            }

            private struct MeasurementResult {
                let duration: Duration
                let stats: MemoryAllocation.AllocationStats
            }
        }

        extension TestingPerformance {
            struct Configuration: Sendable {
                var enabled: Bool
                var iterations: Int
                var warmup: Int
                var printResults: Bool
                var threshold: Duration?
                var metric: Metric
                var trackAllocations: Bool
                var maxAllocations: Int?
                var detectLeaks: Bool
                var peakMemoryLimit: Int?

                init(
                    enabled: Bool = true,
                    iterations: Int = 10,
                    warmup: Int = 0,
                    printResults: Bool = false,
                    threshold: Duration? = nil,
                    metric: Metric = .median,
                    trackAllocations: Bool = true,
                    maxAllocations: Int? = nil,
                    detectLeaks: Bool = false,
                    peakMemoryLimit: Int? = nil
                ) {
                    self.enabled = enabled
                    self.iterations = iterations
                    self.warmup = warmup
                    self.printResults = printResults
                    self.threshold = threshold
                    self.metric = metric
                    self.trackAllocations = trackAllocations
                    self.maxAllocations = maxAllocations
                    self.detectLeaks = detectLeaks
                    self.peakMemoryLimit = peakMemoryLimit
                }

                func merged(with other: Configuration) -> Configuration {
                    Configuration(
                        enabled: other.enabled,
                        iterations: other.iterations,
                        warmup: other.warmup,
                        printResults: other.printResults,
                        threshold: other.threshold ?? self.threshold,
                        metric: other.metric,
                        trackAllocations: other.trackAllocations,
                        maxAllocations: other.maxAllocations ?? self.maxAllocations,
                        detectLeaks: other.detectLeaks,
                        peakMemoryLimit: other.peakMemoryLimit ?? self.peakMemoryLimit
                    )
                }
            }
        }

        // MARK: - Public API

        extension Trait where Self == _PerformanceTrait {
            /// Measure test execution time with detailed statistics
            ///
            /// Automatically prints performance measurements and optionally enforces
            /// a performance threshold.
            ///
            /// Basic usage:
            /// ```swift
            /// @Test(.timed())
            /// func operation() {
            ///     numbers.sum()
            /// }
            /// ```
            ///
            /// With threshold enforcement:
            /// ```swift
            /// @Test(.timed(threshold: .milliseconds(50)))
            /// func fastOperation() {
            ///     numbers.sum()
            /// }
            /// ```
            ///
            /// Custom configuration:
            /// ```swift
            /// @Test(.timed(iterations: 100, warmup: 5, threshold: .milliseconds(10)))
            /// func preciseOperation() {
            ///     numbers.sum()
            /// }
            /// ```
            ///
            /// With allocation limit:
            /// ```swift
            /// @Test(.timed(threshold: .milliseconds(30), maxAllocations: 1024))
            /// func noExtraAllocations() {
            ///     numbers.sum()  // Should iterate without copying
            /// }
            /// ```
            ///
            /// For pure timing without allocation tracking overhead:
            /// ```swift
            /// @Test(.timed(trackAllocations: false))
            /// func lowOverheadBenchmark() {
            ///     // Allocation tracking disabled for minimal measurement overhead
            ///     expensiveOperation()
            /// }
            /// ```
            ///
            /// - Parameters:
            ///   - iterations: Number of measurement runs (default: 10)
            ///   - warmup: Number of untimed warmup runs (default: 0)
            ///   - threshold: Optional performance budget - test fails if exceeded
            ///   - trackAllocations: Whether to track memory allocations (default: true).
            ///     Set to `false` for lower measurement overhead when allocation stats aren't needed.
            ///   - maxAllocations: Optional memory allocation limit in bytes - test fails if exceeded
            ///   - metric: Metric to check against threshold (default: .median)
            ///
            /// - Note: Always prints performance statistics. Use `.serialized` on suite
            ///   to avoid interference between tests.
            public static func timed(
                iterations: Int = 10,
                warmup: Int = 0,
                threshold: Duration? = nil,
                trackAllocations: Bool = true,
                maxAllocations: Int? = nil,
                metric: TestingPerformance.Metric = .median,
                detectLeaks: Bool = false,
                peakMemoryLimit: Int? = nil,
                sourceLocation: SourceLocation = #_sourceLocation
            ) -> Self {
                Self(
                    configuration: TestingPerformance.Configuration(
                        iterations: iterations,
                        warmup: warmup,
                        printResults: true,
                        threshold: threshold,
                        metric: metric,
                        trackAllocations: trackAllocations,
                        maxAllocations: maxAllocations,
                        detectLeaks: detectLeaks,
                        peakMemoryLimit: peakMemoryLimit
                    ),
                    sourceLocation: sourceLocation
                )
            }

            /// Enable memory leak detection for performance tests
            ///
            /// Automatically detects memory leaks during test execution.
            /// Test fails if net allocations remain after completion.
            ///
            /// ```swift
            /// @Test(.timed(), .detectLeaks())
            /// func `no memory leaks`() {
            ///     // Test automatically fails if memory leaks
            /// }
            /// ```
            public static func detectLeaks(
                sourceLocation: SourceLocation = #_sourceLocation
            ) -> Self {
                Self(
                    configuration: TestingPerformance.Configuration(
                        detectLeaks: true
                    ),
                    sourceLocation: sourceLocation
                )
            }

            /// Track peak memory usage with optional limit
            ///
            /// Monitors peak memory throughout test iterations.
            /// Test fails if peak exceeds specified limit.
            ///
            /// ```swift
            /// @Test(.timed(), .trackPeakMemory(limit: 10_000_000))
            /// func `stay under memory budget`() {
            ///     // Test fails if peak memory exceeds 10MB
            /// }
            /// ```
            ///
            /// - Parameter limit: Optional maximum peak memory in bytes
            public static func trackPeakMemory(
                limit: Int? = nil,
                sourceLocation: SourceLocation = #_sourceLocation
            ) -> Self {
                Self(
                    configuration: TestingPerformance.Configuration(
                        peakMemoryLimit: limit
                    ),
                    sourceLocation: sourceLocation
                )
            }
        }

    #endif  // compiler(>=6.0)
#endif  // canImport(Testing)
