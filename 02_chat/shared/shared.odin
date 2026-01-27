package shared

import "core:fmt"
import "core:mem"
import enet "vendor:ENet"

format_enet_address :: proc(addr: enet.Address) -> string {
    return fmt.tprintf(
        "%d.%d.%d.%d:%d",
        u8(addr.host),
        u8(addr.host >> 8),
        u8(addr.host >> 16),
        u8(addr.host >> 24),
        addr.port,
    )
}

review_tracking_allocators :: proc(track, temp_track: ^mem.Tracking_Allocator) {
    if len(track.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
        for _, entry in track.allocation_map {
            fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
    }
    if len(track.bad_free_array) > 0 {
        fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
        for entry in track.bad_free_array {
            fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
        }
    }
    mem.tracking_allocator_destroy(track)

    if len(temp_track.allocation_map) > 0 {
        fmt.eprintf("=== %v temp allocations not freed:!!! ===\n", len(temp_track.allocation_map))
        for _, entry in temp_track.allocation_map {
            fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
    }
    if len(temp_track.bad_free_array) > 0 {
        fmt.eprintf("=== %v temp incorrect frees: ===\n", len(temp_track.bad_free_array))
        for entry in temp_track.bad_free_array {
            fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
        }
    }
    mem.tracking_allocator_destroy(temp_track)
}
