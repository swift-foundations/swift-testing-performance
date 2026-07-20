// AllocationStats.swift
// MemoryAllocation
//
// Memory allocation statistics

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

#if os(Linux)
    import CAllocationTracking
#endif

/// Memory allocation statistics
///
/// Represents the allocation behavior of a code section, including
/// the number of allocations, deallocations, and total bytes allocated.
///
/// Example:
/// ```swift
/// let stats = AllocationStats.capture()
/// print("Allocations: \(stats.allocations)")
/// print("Bytes: \(stats.bytesAllocated)")
/// print("Net: \(stats.netAllocations)")
/// ```
public struct AllocationStats: Sendable, Equatable {
    /// Total number of allocations
    public let allocations: Int

    /// Total number of deallocations
    public let deallocations: Int

    /// Total bytes allocated
    public let bytesAllocated: Int

    /// Net allocations (allocations - deallocations)
    ///
    /// A positive value indicates potential memory leaks.
    public var netAllocations: Int {
        allocations - deallocations
    }

    /// Net bytes (bytes that haven't been freed)
    ///
    /// This is an approximation as we don't track individual allocation sizes on deallocation.
    public var netBytes: Int {
        bytesAllocated
    }

    /// Initialize allocation statistics
    ///
    /// - Parameters:
    ///   - allocations: Number of allocations
    ///   - deallocations: Number of deallocations
    ///   - bytesAllocated: Total bytes allocated
    public init(allocations: Int = 0, deallocations: Int = 0, bytesAllocated: Int = 0) {
        self.allocations = allocations
        self.deallocations = deallocations
        self.bytesAllocated = bytesAllocated
    }

    /// Calculate the delta between two allocation statistics
    ///
    /// - Parameters:
    ///   - start: Starting statistics
    ///   - end: Ending statistics
    /// - Returns: The delta between the two statistics
    public static func delta(
        from start: AllocationStats,
        to end: AllocationStats
    ) -> AllocationStats {
        AllocationStats(
            allocations: end.allocations - start.allocations,
            deallocations: end.deallocations - start.deallocations,
            bytesAllocated: end.bytesAllocated - start.bytesAllocated
        )
    }

    /// Capture current allocation statistics
    ///
    /// Platform-specific implementation that tracks memory allocations.
    /// Returns zero stats if allocation tracking is unavailable.
    ///
    /// - Returns: Current allocation statistics
    public static func capture() -> AllocationStats {
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
            return captureDarwin()
        #elseif os(Linux)
            return captureLinux()
        #else
            return AllocationStats()
        #endif
    }

    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        private static func captureDarwin() -> AllocationStats {
            //  Note: malloc_zone_statistics returns process-wide stats
            // For thread-local tracking, use .serialized trait on test suites
            var stats = malloc_statistics_t()
            malloc_zone_statistics(nil, &stats)

            return AllocationStats(
                allocations: Int(stats.blocks_in_use),
                deallocations: 0,  // Not directly available from malloc_statistics_t
                bytesAllocated: Int(stats.size_in_use)
            )
        }
    #endif

    #if os(Linux)
        private static func captureLinux() -> AllocationStats {
            let stats = tracking_current()
            return AllocationStats(
                allocations: Int(stats.allocations),
                deallocations: Int(stats.deallocations),
                bytesAllocated: Int(stats.bytes_allocated)
            )
        }
    #endif
}

#if os(Linux)
    extension AllocationStats {
        /// Start tracking allocations on Linux
        ///
        /// This enables the LD_PRELOAD malloc/free hooks.
        /// Must be called before measuring allocations.
        ///
        /// Note: Requires LD_PRELOAD setup for thread-local tracking.
        public static func startTracking() {
            tracking_start()
        }

        /// Stop tracking allocations and return final statistics
        ///
        /// - Returns: Final allocation statistics since startTracking()
        public static func stopTracking() -> AllocationStats {
            let stats = tracking_stop()
            return AllocationStats(
                allocations: Int(stats.allocations),
                deallocations: Int(stats.deallocations),
                bytesAllocated: Int(stats.bytes_allocated)
            )
        }

        /// Reset tracking statistics to zero
        ///
        /// Keeps tracking enabled but resets counters.
        public static func resetTracking() {
            tracking_reset()
        }
    }
#endif
