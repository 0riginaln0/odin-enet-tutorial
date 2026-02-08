package common

import "core:fmt"
import "core:mem"
import enet "vendor:ENet"
import rl "vendor:raylib"

Server_To_Client_Message :: union {
    World_Update,
    Slot_Assignment,
}

World_Update :: World
Slot_Assignment :: struct {
    index: u8,
}

World :: struct {
    player_slots: [3]Player_Slot,
}

Player_Slot :: union {
    Free,
    Player,
}
Free :: struct {}
Player :: struct {
    color:    rl.Color,
    position: rl.Vector2,
}

Client_To_Server_Message :: union {
    Player_Input,
    Chat_Message,
}
Player_Input :: struct {
    id:      int,
    buttons: bit_set[Buttons],
}
Chat_Message :: struct {
    id:      int,
    buttons: string,
}
Buttons :: enum {
    Up,
    Down,
    Left,
    Right,
}

// Creates a temporarly allocated string
format_enet_address :: proc(addr: enet.Address) -> string {
    return fmt.tprintf("%d.%d.%d.%d:%d", u8(addr.host), u8(addr.host >> 8), u8(addr.host >> 16), u8(addr.host >> 24), addr.port)
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
