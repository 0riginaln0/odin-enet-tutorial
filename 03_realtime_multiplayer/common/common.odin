package common

import "core:fmt"
import "core:mem"
import enet "vendor:ENet"
import rl "vendor:raylib"
import "core:encoding/cbor"

Channels :: enum u8 {
  Default, // Input and world updates
  Reliable, // Chat messages
}

Server_To_Client_Message :: union {
  World_Update,
  Slot_Assignment,
  Chat_Message,
}
Chat_Message :: struct {
  i: u8,
  m: string,
}
World_Update :: World
Slot_Assignment :: u8

Client_To_Server_Message :: union {
  Player_Input,
  Chat_Message,
}
Player_Input :: struct {
  id:      int,
  buttons: bit_set[Buttons],
}
Buttons :: enum {
  Up,
  Down,
  Left,
  Right,
}

MAX_PLAYERS_COUNT :: 4

World :: struct {
  player_slots: [MAX_PLAYERS_COUNT]Player_Slot,
}

Player_Slot :: union #no_nil {
  Free,
  Player,
}
Free :: struct {}
Player :: struct {
  color:    rl.Color,
  position: rl.Vector2,
  buttons:  bit_set[Buttons],
}

// Creates a temporarly allocated string
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

check_tracking_allocators :: proc(track, temp_track: ^mem.Tracking_Allocator) {
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

/* ENCODERS & DECODERS */

encode_server_message :: proc(
  msg: Server_To_Client_Message,
  allocator := context.allocator,
) -> (
  []byte,
  bool,
) {
  data, err := cbor.marshal_into_bytes(msg, allocator = allocator)
  if err != nil {
    fmt.eprintln("Failed to marshal server message:", err)
    return nil, false
  }
  return data, true
}

decode_server_message :: proc(
  data: []byte,
  allocator := context.allocator,
) -> (
  Server_To_Client_Message,
  bool,
) {
  msg: Server_To_Client_Message
  err := cbor.unmarshal_from_bytes(data, &msg, allocator = allocator)
  if err != nil {
    fmt.eprintln("Failed to unmarshal server message:", err)
    return msg, false
  }
  return msg, true
}

encode_client_message :: proc(
  msg: Client_To_Server_Message,
  allocator := context.allocator,
) -> (
  []byte,
  bool,
) {
  data, err := cbor.marshal_into_bytes(msg, allocator = allocator)
  if err != nil {
    fmt.eprintln("Failed to marshal client message:", err)
    return nil, false
  }
  return data, true
}

decode_client_message :: proc(
  data: []byte,
  allocator := context.allocator,
) -> (
  Client_To_Server_Message,
  bool,
) {
  msg: Client_To_Server_Message
  err := cbor.unmarshal_from_bytes(data, &msg, allocator = allocator)
  if err != nil {
    fmt.eprintln("Failed to unmarshal client message:", err)
    return msg, false
  }
  return msg, true
}

main :: proc() {
  fmt.println("What's up")
  a: Server_To_Client_Message
  a = World_Update {
    player_slots = {
      Free{},
      Player{color = {255, 255, 0, 255}, position = {41, 42}, buttons = {.Up, .Down}},
      Free{},
      Free{},
    },
  }

  data, err := encode_server_message(a)
  fmt.println(data)
  fmt.println(len(data))
  aa, _ := decode_server_message(data)
  fmt.println(aa)



  b: Client_To_Server_Message
  b = Player_Input {
    id = 3,
    buttons = {.Up, .Down}
  }
  data, err = encode_client_message(b)
  fmt.println(data)
  bb, _ := decode_client_message(data)
  fmt.println(bb)
}
