package server

import common "../common"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"
import enet "vendor:ENet"
import rl "vendor:raylib"

WORLD_WIDTH :: 600
WORLD_HEIGHT :: 600
RIGHT_BOUND :: 0 + WORLD_WIDTH
LEFT_BOUND :: 0
UP_BOUND :: 0
DOWN_BOUND :: 0 + WORLD_HEIGHT

Game :: struct {
  world:      common.World,
  prev_world: common.World,
  slot_peers: [common.MAX_PLAYERS_COUNT]^enet.Peer,
}

main :: proc() {
  track: mem.Tracking_Allocator; mem.tracking_allocator_init(&track, context.allocator)
  temp_track: mem.Tracking_Allocator; mem.tracking_allocator_init(&temp_track, context.temp_allocator)
  context.allocator = mem.tracking_allocator(&track)
  context.temp_allocator = mem.tracking_allocator(&temp_track)
  defer common.review_tracking_allocators(&track, &temp_track)

  if enet.initialize() != 0 {
    fmt.println("An error occured while initializing ENet!")
    return
  }
  defer enet.deinitialize()

  address: enet.Address = {
    host = enet.HOST_ANY,
    port = 27585,
  }
  CHANNEL_LIMIT :: 3
  server: ^enet.Host = enet.host_create(&address, 15, CHANNEL_LIMIT, 0, 0)
  if server == nil {
    fmt.println("An error occured while trying to create an ENet host")
    return
  }
  defer enet.host_destroy(server)
  event: enet.Event

  /*
    Fixed tick rate
    Accumulate time and only tick as many frames as time has actually been accumulated
  */
  TICK_RATE :: 100 // Frequency in Hertz at which a game server updates the game state
  DT :: 1 * time.Second / TICK_RATE
  fmt.println(DT)
  tick := time.tick_now()
  accumulator: time.Duration = DT

  last_review := time.now()

  game: Game

  for {
    defer if time.since(last_review) >= 10 * time.Second {
      fmt.println("Check for allocations")
      common.check_tracking_allocators(&track, &temp_track)
      last_review = time.now()
    }

    defer free_all(context.temp_allocator)
    // Handle inputs
    handle_incoming_events(server, &game, &event)

    for ; accumulator >= DT; accumulator -= DT {
      world_update(&game.world)

      if game.world == game.prev_world do continue
      game.prev_world = game.world

      // Send updated world to connected peers
      world_msg: common.Server_To_Client_Message = game.world
      data, ok := common.encode_server_message(world_msg, context.temp_allocator)
      if !ok {
        fmt.eprintln("Failed to encode world update")
        continue
      }
      packet := enet.packet_create(raw_data(data), len(data), {})
      enet.host_broadcast(server, u8(common.Channels.Default), packet)
    }

    time_passed_since_last_tick := time.tick_lap_time(&tick)
    accumulator += time_passed_since_last_tick
  }
}

next_color :: proc() -> rl.Color {
  @(static) current_color := rl.RED

  if current_color == rl.RED {
    current_color = rl.BLUE
  } else if current_color == rl.BLUE {
    current_color = rl.GREEN
  } else if current_color == rl.GREEN {
    current_color = rl.ORANGE
  } else if current_color == rl.ORANGE {
    current_color = rl.RED
  }

  return current_color
}

handle_incoming_events :: proc(server: ^enet.Host, game: ^Game, event: ^enet.Event) {
  if enet.host_service(server, event, 0) <= 0 do return

  #partial switch event.type {
  case .CONNECT:
    fmt.printfln("New client connected from %s", common.format_enet_address(event.peer.address))
    slot_id, found := find_free_slot(&game.world)
    if !found {
      fmt.println("SERVER IS FULL")
      enet.peer_disconnect_now(event.peer, 1)
      return
    }
    fmt.println("FOUND FREE SLOT")
    game.slot_peers[slot_id] = event.peer

    game.world.player_slots[slot_id] = common.Player {
      color    = next_color(),
      position = {WORLD_WIDTH / 2, WORLD_HEIGHT / 2},
      buttons  = {},
    }

    // Send the slot assignment to the client
    slot_msg: common.Server_To_Client_Message = common.Slot_Assignment(slot_id)
    data, ok := common.encode_server_message(slot_msg, context.temp_allocator)
    if !ok {
      fmt.eprintln("Failed to encode slot assignment")
      enet.peer_disconnect_now(event.peer, 1)
      game.slot_peers[slot_id] = nil
      game.world.player_slots[slot_id] = common.Free{}
      return
    }
    packet := enet.packet_create(raw_data(data), len(data), {.RELIABLE})
    enet.peer_send(event.peer, u8(common.Channels.Reliable), packet)
    fmt.printfln("Assigned slot %d to peer", slot_id)

  case .RECEIVE:
    fmt.println("RECEIVED SOMETHING")
    // The packet contained in the "packet" field must be destroyed
    // with enet_packet_destroy() when you are done inspecting its contents.
    defer enet.packet_destroy(event.packet)
    fmt.printf(
      "A packet of length %d containing %s was received from %s on channel %d.\n",
      event.packet.dataLength,
      event.packet.data,
      common.format_enet_address(event.peer.address),
      event.channelID,
    )

    // Find slot which belongs to the peer. Ignore if not found
    slot_idx := slot_from_peer(game, event.peer)
    if slot_idx == -1 {
      fmt.printfln("Received message from unknown peer, ignoring")
      return
    }

    // Decode the client message
    client_msg, ok := common.decode_client_message(
      event.packet.data[:event.packet.dataLength],
      context.temp_allocator,
    )
    if !ok {
      fmt.eprintfln("Failed to decode client message from slot %d", slot_idx)
      return
    }

    // Handle the message
    switch v in client_msg {
    case common.Player_Input:
      #partial switch &p in game.world.player_slots[slot_idx] {
      case common.Player:
        p.buttons = v.buttons
      }
    case common.Chat_Message:
      chat_broadcast: common.Server_To_Client_Message = common.Chat_Message {
        i = v.i,
        m = v.m,
      }
      data, ok := common.encode_server_message(chat_broadcast, context.temp_allocator)
      if ok {
        packet := enet.packet_create(raw_data(data), len(data), {.RELIABLE})
        enet.host_broadcast(server, u8(common.Channels.Reliable), packet)
      }
    }
  case .DISCONNECT:
    fmt.println("DISCONNECTED SOMEBODY")
    // Find the slot that used this peer
    slot_idx := slot_from_peer(game, event.peer)
    if slot_idx != -1 {
      game.slot_peers[slot_idx] = nil
      game.world.player_slots[slot_idx] = common.Free{}
      fmt.printfln("Slot %d freed", slot_idx)
    }
    // Only the "peer" field of the event structure is valid for this event
    fmt.printfln(
      "peer %s either explicitly disconnected or timed out",
      common.format_enet_address(event.peer.address),
    )
    /* Reset the peer's client information. */
    event.peer.data = nil
  }
}

find_free_slot :: proc(world: ^common.World) -> (u8, bool) {
  fmt.println("Checking slots, length =", len(world.player_slots))

  for slot, i in world.player_slots {
    fmt.println(slot)
    if _, is_free_slot := slot.(common.Free); is_free_slot do return u8(i), true
  }
  return 0, false
}

// Helper to get the slot index of a peer (or -1 if not found)
slot_from_peer :: proc(game: ^Game, peer: ^enet.Peer) -> int {
  for p, i in game.slot_peers {
    if p == peer do return i
  }
  return -1
}

world_update :: proc(world: ^common.World) {
  for i in 0 ..< len(world.player_slots) {
    #partial switch &player in world.player_slots[i] {
    case common.Player:
      if .Up in player.buttons do player.position.y -= 1
      if .Down in player.buttons do player.position.y += 1
      if .Left in player.buttons do player.position.x -= 1
      if .Right in player.buttons do player.position.x += 1

      if player.position.x > RIGHT_BOUND do player.position.x = RIGHT_BOUND
      if player.position.x < LEFT_BOUND do player.position.x = LEFT_BOUND
      if player.position.y > DOWN_BOUND do player.position.y = DOWN_BOUND
      if player.position.y < UP_BOUND do player.position.y = UP_BOUND
    }
  }
}
