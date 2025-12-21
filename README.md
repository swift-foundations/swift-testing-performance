# swift-testing-performance

[![CI](https://github.com/coenttb/swift-testing-performance/workflows/CI/badge.svg)](https://github.com/coenttb/swift-testing-performance/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Performance testing infrastructure for Swift Testing framework with statistical analysis, performance budgets, and memory allocation tracking.

## Overview

swift-testing-performance provides declarative performance testing using Swift Testing's trait system. It integrates statistical metrics, automatic threshold enforcement, and memory allocation tracking into Swift Testing's workflow without external dependencies.

The package enables performance regression detection in CI pipelines through trait-based API, comprehensive statistical analysis, and zero-dependency implementation using only Swift standard library and platform math libraries (Darwin/Glibc).

## Features

- **Swift Testing Integration**: Declarative `.timed()` trait for performance testing with automatic statistical reporting
- **Statistical Metrics**: Comprehensive analysis including min, median, mean, p95, p99, max, and standard deviation
- **Performance Budgets**: Automatic test failures when median exceeds defined thresholds
- **Memory Allocation Tracking**: Platform-specific malloc statistics to enforce zero-allocation algorithms
- **Memory Leak Detection**: Automatic leak detection with `.detectLeaks()` trait powered by swift-memory-allocation
- **Peak Memory Tracking**: Monitor and enforce peak memory budgets with `.trackPeakMemory(limit:)` trait
- **Flexible Measurement API**: Both trait-based (`@Test(.timed())`) and manual (`TestingPerformance.measure()`) measurement
- **Cross-Platform**: Works on macOS/iOS/watchOS/tvOS and Linux
- **High Precision**: Int128-based Duration division for attosecond-level precision

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-testing-performance", from: "1.0.0")
]
```

### Requirements

- Swift 6.0+
- macOS 15.0+, iOS 18.0+, watchOS 11.0+, tvOS 18.0+
- Swift Testing framework

## Quick Start

### Basic Performance Test

```swift
import Testing
import TestingPerformance

@Test(.timed())
func `array reduce performance`() {
    let numbers = Array(1...100_000)
    _ = numbers.reduce(0, +)
}
```

Output:
```
⏱️ `array reduce performance`()
   Iterations: 10
   Min:        25.18ms
   Median:     25.51ms
   Mean:       25.61ms
   p95:        26.83ms
   p99:        26.83ms
   Max:        26.83ms
   StdDev:     466.95µs
```

### With Performance Budget

```swift
@Test(.timed(threshold: .milliseconds(30)))
func `must complete within 30ms`() {
    let numbers = Array(1...100_000)
    _ = numbers.reduce(0, +)
}
```

Test fails if median exceeds 30ms with detailed error:
```
Performance threshold exceeded in 'must complete within 30ms':
Expected median: < 30.00ms
Actual median: 35.42ms
```

### Memory Allocation Tracking

```swift
@Test(.timed(threshold: .milliseconds(30), maxAllocations: 60_000))
func `zero-allocation iteration`() {
    let numbers = Array(1...100_000)
    _ = numbers.reduce(0, +)
}
```

Output includes allocation statistics:
```
   Allocations:
     Min:      0 bytes
     Median:   0 bytes
     Max:      49.06 KB
     Avg:      4.91 KB
```

Median of 0 bytes proves the algorithm is allocation-free.

### Memory Leak Detection

Automatically detect memory leaks during test execution:

```swift
@Test(.timed(), .detectLeaks())
func `no memory leaks in cache`() {
    var cache: [String: Data] = [:]

    // Add items
    for i in 0..<100 {
        cache["key\(i)"] = Data(count: 1024)
    }

    // Clear cache - test fails if memory not released
    cache.removeAll()
}
```

Test fails if net allocations remain after completion:
```
Memory leak detected in 'no memory leaks in cache':
Net allocations: 15
Net bytes: 102.40 KB
```

**Note**: Memory leak detection tracks net allocations during test execution. Background system allocations (runtime housekeeping, ARC cleanup) may occasionally trigger false positives. For reliable leak detection:
- Use `.serialized` test execution to minimize interference
- Test in controlled environments where possible
- Focus on detecting significant leaks rather than zero allocations
- Consider the operational environment when setting expectations

### Peak Memory Tracking

Monitor and enforce peak memory budgets:

```swift
@Test(.timed(), .trackPeakMemory(limit: 10_000_000))
func `stay under 10MB budget`() {
    var data: [[UInt8]] = []

    for i in 0..<100 {
        data.append(Array(repeating: UInt8(i), count: 10_000))
    }

    // Peak memory tracked across all iterations
}
```

Output includes peak memory usage:
```
⏱️ `stay under 10MB budget`()
   Iterations: 10
   Min:        2.45ms
   Median:     2.67ms
   Mean:       2.71ms
   p95:        3.12ms
   p99:        3.12ms
   Max:        3.12ms
   StdDev:     185.23µs
   Peak Memory: 9.77 MB
```

Test fails if peak exceeds limit:
```
Peak memory limit exceeded in 'stay under 10MB budget':
Limit: 10.00 MB
Actual peak: 12.45 MB
Exceeded by: 2.45 MB
```

### Combining Traits

Combine multiple performance and memory traits:

```swift
@Test(
    .timed(threshold: .milliseconds(100)),
    .detectLeaks(),
    .trackPeakMemory(limit: 5_000_000)
)
func `comprehensive performance test`() {
    // Test must:
    // - Complete within 100ms
    // - Not leak memory
    // - Stay under 5MB peak memory
}
```

## Usage Examples

### Organizing Performance Tests

Use serialized test execution to prevent interference:

```swift
import Testing
import TestingPerformance

@Suite(.serialized)
struct PerformanceTests {}

extension PerformanceTests {
    @Suite(.serialized)
    struct `Array Performance` {

        @Test(.timed(threshold: .milliseconds(30)))
        func `sum 100k elements`() {
            let numbers = Array(1...100_000)
            _ = numbers.reduce(0, +)
        }

        @Test(.timed(threshold: .milliseconds(50)))
        func `map 100k elements`() {
            let numbers = Array(1...100_000)
            _ = numbers.map { $0 * 2 }
        }
    }
}
```

### Manual Measurement API

For custom measurement scenarios outside Swift Testing:

```swift
import TestingPerformance

// Statistical measurement
let (result, measurement) = TestingPerformance.measure(iterations: 100) {
    expensiveOperation()
}

print("Median: \(TestingPerformance.formatDuration(measurement.median))")
print("p95: \(TestingPerformance.formatDuration(measurement.p95))")

// Single-shot timing
let (quickResult, duration) = TestingPerformance.time {
    oneTimeOperation()
}

// Async operations
let (asyncResult, asyncMeasurement) = await TestingPerformance.measure {
    await asyncOperation()
}
```

### Performance Assertions

```swift
// Assert performance threshold
TestingPerformance.expectPerformance(lessThan: .milliseconds(100)) {
    operation()
}

// Regression detection
let baseline = TestingPerformance.Measurement(
    durations: Array(repeating: .milliseconds(10), count: 10)
)
let current = TestingPerformance.measure { operation() }.measurement

TestingPerformance.expectNoRegression(
    current: current,
    baseline: baseline,
    tolerance: 0.10  // Allow 10% regression
)
```

### Performance Suite API

Compare multiple related operations:

```swift
var suite = PerformanceSuite(name: "String Operations")

suite.benchmark("concatenation") {
    var result = ""
    for i in 1...1000 {
        result += String(i)
    }
}

suite.benchmark("interpolation") {
    var result = ""
    for i in 1...1000 {
        result += "\(i)"
    }
}

suite.benchmark("joined") {
    let parts = (1...1000).map(String.init)
    _ = parts.joined()
}

suite.printReport()
```

Output:
```
╔══════════════════════════════════════════════════════════╗
║  String Operations                                       ║
╚══════════════════════════════════════════════════════════╝

  concatenation   5.23ms
  interpolation   4.87ms
  joined          1.42ms
```

### Trait API

The `.timed()` trait supports comprehensive configuration:

```swift
@Test(.timed(
    iterations: 10,           // Number of measurement runs (default: 10)
    warmup: 0,                // Warmup runs before measurement (default: 0)
    threshold: .milliseconds(30),  // Optional performance budget
    maxAllocations: 60_000,   // Optional allocation limit in bytes
    metric: .median           // Metric for threshold (default: .median)
))
func `performance test`() {
    // Test code
}
```

### Performance Metrics

Choose which metric to enforce thresholds against:

- `.min` - Minimum measured duration
- `.max` - Maximum measured duration
- `.median` - Median duration (default, most stable)
- `.mean` - Mean/average duration
- `.p95` - 95th percentile
- `.p99` - 99th percentile

Example:
```swift
@Test(.timed(threshold: .milliseconds(30), metric: .p95))
func `p95 threshold`() {
    let numbers = Array(1...100_000)
    _ = numbers.reduce(0, +)
}
```

## Best Practices

### Benchmark Fixtures and Timed Regions

For I/O, filesystem, and executor benchmarks, setup and teardown must run **outside** the timed measurement region. Otherwise, file creation, network connections, or executor startup inflate performance numbers.

**Problem**: Setup inside timed region measures the wrong thing:

```swift
// ❌ BAD - file creation is measured
@Suite(.serialized)
struct `File Streaming` {
    @Test(.timed(iterations: 5))
    func stream1MBFile() async throws {
        // This setup is TIMED - inflates results!
        let data = [UInt8](repeating: 0xAB, count: 1_000_000)
        try data.write(to: filePath)

        defer { try? FileManager.default.removeItem(at: filePath) }

        // Actual operation
        for chunk in streamFile(filePath) { }
    }
}
```

**Solution**: Use `final class` suites with `init`/`deinit`:

```swift
// ✅ GOOD - setup/teardown outside timed region
@Suite(.serialized)
final class `File Streaming` {
    let executor: IOExecutor
    let file1MB: URL

    init() async throws {
        // Setup runs ONCE, before any tests
        self.executor = IOExecutor()
        self.file1MB = tempDir.appending("stream.bin")

        let data = [UInt8](repeating: 0xAB, count: 1_000_000)
        try data.write(to: file1MB)
    }

    deinit {
        // Cleanup runs after all tests - synchronous!
        try? FileManager.default.removeItem(at: file1MB)
    }

    @Test(.timed(iterations: 5))
    func stream1MBFile() async throws {
        // Only this code is measured
        for chunk in streamFile(file1MB) { }
    }
}
```

**Key points**:

1. **Use `final class`** not `struct` - enables `deinit` for cleanup
2. **Setup in `init()`** - files, directories, executors created once
3. **Cleanup in `deinit`** - runs synchronously after all tests
4. **Use `.serialized`** - prevents I/O contention between tests
5. **Avoid `defer { Task { ... } }`** - async cleanup can overlap with next test

**Executor startup exception**: If measuring "first job latency including startup", intentionally create the executor inside the timed test:

```swift
@Test(.timed(iterations: 10))
func executorStartupLatency() async throws {
    // Intentionally timed - measures startup cost
    let executor = IOExecutor()
    defer { Task { await executor.shutdown() } }

    _ = try await executor.run { 42 }
}
```

### 1. Separate Correctness from Performance

```swift
// Correctness test
@Test
func `sum returns correct total`() {
    #expect([1, 2, 3].sum() == 6)
}

// Performance test
extension PerformanceTests {
    @Test(.timed(threshold: .milliseconds(30)))
    func `sum is fast`() {
        _ = Array(1...100_000).sum()
    }
}
```

### 2. Use Serialized Execution

Always use `.serialized` for performance test suites to avoid interference:

```swift
@Suite(.serialized)
struct PerformanceTests {}

extension PerformanceTests {
    @Suite(.serialized)
    struct `Sequence Performance` {
        // Tests run one at a time
    }
}
```

### 3. Use Median for Thresholds

Median is more stable than mean for performance thresholds:

```swift
@Test(.timed(threshold: .milliseconds(30), metric: .median))  // ✅ Recommended
@Test(.timed(threshold: .milliseconds(30), metric: .mean))    // ⚠️ Less stable
```

### 4. Add Headroom to Thresholds

Account for system variation with 10-15% headroom:

```swift
// Measured median: 25ms
@Test(.timed(threshold: .milliseconds(30)))  // ✅ 20% headroom
@Test(.timed(threshold: .milliseconds(25)))  // ❌ Too tight, will flake
```

### 5. Adjust Iterations by Runtime

- Fast operations (<1ms): 100+ iterations
- Medium operations (1-100ms): 10-50 iterations
- Slow operations (>100ms): 5-10 iterations

```swift
@Test(.timed(iterations: 100, threshold: .microseconds(50)))
func `fast operation`() { ... }

@Test(.timed(iterations: 10, threshold: .milliseconds(500)))
func `slow operation`() { ... }
```

## Memory Allocation Tracking

TestingPerformance tracks memory allocations during test execution using platform-specific malloc statistics:

- **Darwin**: `malloc_statistics_t` via `malloc_zone_statistics()` (process-wide)
- **Linux**: `mallinfo()` via glibc (process-wide)

### Interpreting Allocation Stats

```
Allocations:
  Min:      0 bytes      ← Best case (no allocations)
  Median:   0 bytes      ← Typical case (50th percentile)
  Max:      49.06 KB     ← Worst case (caught background activity)
  Avg:      4.91 KB      ← Average across all iterations
```

**Key insight**: Median of 0 bytes proves the algorithm is allocation-free. The max captures occasional background system allocations (malloc zone management, runtime housekeeping).

### Setting Allocation Limits

Account for system noise when setting limits:

```swift
// For truly allocation-free algorithms
@Test(.timed(maxAllocations: 60_000))  // ~60KB headroom for system noise
func `zero allocation test`() {
    let numbers = Array(1...100_000)
    var sum = 0
    for num in numbers {
        sum += num
    }
    _ = sum
}
```

### Parallel Test Execution

**Allocation limits use median values**, making them robust to parallel test execution:

```swift
// These tests can run in parallel - median filtering handles interference
@Suite("Parallel Safe")
struct ParallelTests {
    @Test(.timed(maxAllocations: 500_000))
    func test1() { /* allocations */ }

    @Test(.timed(maxAllocations: 500_000))
    func test2() { /* allocations */ }
}
```

On Darwin, `malloc_zone_statistics` returns process-wide statistics. When tests run in parallel:
- Some iterations may capture allocations from concurrent tests
- **Median filtering removes this interference**
- The middle value represents your test's true allocation behavior

For most accurate allocation tracking, use `.serialized`:

```swift
@Suite("Allocation Tracking", .serialized)
struct AllocationTests {
    // Tests run sequentially - no interference
}
```

## Related Projects

### swift-memory-allocation

swift-testing-performance is built on [swift-memory-allocation](https://github.com/coenttb/swift-memory-allocation), which provides the underlying memory tracking infrastructure:

- **AllocationTracker**: Measure memory allocations in code blocks
- **LeakDetector**: Detect memory leaks by tracking net allocations
- **PeakMemoryTracker**: Monitor peak memory usage over time
- **AllocationProfiler**: Profile allocations with statistics and histograms

While swift-memory-allocation provides low-level memory observability, swift-testing-performance integrates it seamlessly into Swift Testing with declarative traits and automatic failure reporting.

### Swift Benchmark

- **swift-testing-performance**: Regression testing with performance budgets in your Swift Testing suite for CI pipelines
- **swift-benchmark**: Dedicated microbenchmarking for comparing algorithms across runs/machines with detailed analysis

Use both: swift-testing-performance for CI regression gates, Benchmark for detailed performance profiling.

## License

This project is licensed under the Apache 2.0 License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

## Author

[Coen ten Thije Boonkkamp](https://github.com/coenttb)
