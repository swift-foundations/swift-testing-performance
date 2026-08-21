#ifndef ALLOCATION_TRACKING_H
#define ALLOCATION_TRACKING_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Allocation statistics structure
typedef struct {
    uint64_t allocations;
    uint64_t deallocations;
    uint64_t bytes_allocated;
} AllocationStats;

// Start tracking allocations for the current thread
void tracking_start(void);

// Stop tracking and return statistics
AllocationStats tracking_stop(void);

// Get current statistics without stopping
AllocationStats tracking_current(void);

// Reset statistics to zero without stopping tracking
void tracking_reset(void);

#ifdef __cplusplus
}
#endif

#endif // ALLOCATION_TRACKING_H
