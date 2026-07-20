#define _GNU_SOURCE
#include "include/allocation_tracking.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

// Thread-local storage for tracking state
static __thread int tracking_enabled = 0;
static __thread AllocationStats stats = {0};

// Original malloc/free function pointers
static void* (*real_malloc)(size_t) = NULL;
static void (*real_free)(void*) = NULL;
static pthread_once_t init_once = PTHREAD_ONCE_INIT;

// Initialize function pointers
static void init_hooks(void) {
    real_malloc = dlsym(RTLD_NEXT, "malloc");
    real_free = dlsym(RTLD_NEXT, "free");
}

// Custom malloc implementation
void* malloc(size_t size) {
    pthread_once(&init_once, init_hooks);

    void* ptr = real_malloc(size);

    if (tracking_enabled && ptr != NULL) {
        stats.allocations++;
        stats.bytes_allocated += size;
    }

    return ptr;
}

// Custom free implementation
void free(void* ptr) {
    pthread_once(&init_once, init_hooks);

    if (tracking_enabled && ptr != NULL) {
        stats.deallocations++;
    }

    real_free(ptr);
}

// Start tracking allocations
void tracking_start(void) {
    memset(&stats, 0, sizeof(stats));
    tracking_enabled = 1;
}

// Stop tracking and return statistics
AllocationStats tracking_stop(void) {
    tracking_enabled = 0;
    return stats;
}

// Get current statistics without stopping
AllocationStats tracking_current(void) {
    return stats;
}

// Reset statistics to zero without stopping tracking
void tracking_reset(void) {
    memset(&stats, 0, sizeof(stats));
}
