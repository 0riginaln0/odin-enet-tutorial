package client

import "core:fmt"
import "core:mem"
import enet "vendor:ENet"
import rl "vendor:raylib"

import common "../common"

GameState :: enum {
  Disconnected,
  Connecting,
  Connected,
}

world: common.World
slot_id: u8 // assigned by server
peer: ^enet.Peer // saved for sending messages

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

  CHANNEL_LIMIT :: 3
  client_host: ^enet.Host = enet.host_create(nil, 1, CHANNEL_LIMIT, 0, 0)
  if client_host == nil {
    fmt.println("An error occured while trying to create an ENet host")
    return
  }
  defer enet.host_destroy(client_host)

  address: enet.Address
  enet.address_set_host(&address, "127.0.0.1")
  address.port = 27585

  // Start connecting immediately
  peer = enet.host_connect(client_host, &address, CHANNEL_LIMIT, 0)
  if peer == nil {
    fmt.println("Failed to initiate a connection to a foreign host")
    return
  }

  state := GameState.Connecting

  rl.InitWindow(800, 600, "Game Client")
  rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
  defer rl.CloseWindow()

  input := common.Player_Input{}
  prev_input := input

  for !rl.WindowShouldClose() {
    defer free_all(context.temp_allocator)
    event: enet.Event
    for enet.host_service(client_host, &event, 0) > 0 {
      #partial switch event.type {
      case .CONNECT:
        fmt.println("Connected to server")
        state = .Connected
        // Reset any local state
        slot_id = 0
        world = {}
      case .RECEIVE:
        handle_server_message(event.packet.data[:event.packet.dataLength])
        enet.packet_destroy(event.packet)
      case .DISCONNECT:
        fmt.println("Disconnected from server")
        state = .Disconnected
        peer = nil
      }
    }

    // Update and render based on state
    switch state {
    case .Disconnected:
      disconnected(&state, client_host, &address)
    case .Connecting:
      connecting()
    case .Connected:
      input.buttons = {}
      if rl.IsKeyDown(.W) do input.buttons += {.Up}
      if rl.IsKeyDown(.S) do input.buttons += {.Down}
      if rl.IsKeyDown(.A) do input.buttons += {.Left}
      if rl.IsKeyDown(.D) do input.buttons += {.Right}
      input.id = int(slot_id)

      if peer != nil {
        if input != prev_input {
          send_player_input(peer, input)
          prev_input = input
        }
        if rl.IsKeyDown(.ONE) {
          send_player_message(peer, "Hello!")
        }
        if rl.IsKeyDown(.TWO) {
          send_player_message(peer, "This game is awesome!")
        }
        if rl.IsKeyDown(.THREE) {
          send_player_message(peer, "gtg bb")
        }
      }

      connected()
    }
  }
}

// Handle messages from server
handle_server_message :: proc(data: []byte) {
  msg, ok := common.decode_server_message(data, context.temp_allocator)
  if !ok {
    fmt.eprintln("Failed to decode server message")
    return
  }

  #partial switch v in msg {
  case common.Slot_Assignment:
    slot_id = v
    fmt.printfln("Assigned slot: %d", slot_id)
  case common.World_Update:
    world = v
  case common.Chat_Message:
    fmt.printfln("[Chat] Player %d: %s", v.i, v.m)
  }
}

send_player_input :: proc(peer: ^enet.Peer, input: common.Player_Input) {
  msg: common.Client_To_Server_Message = input
  data, ok := common.encode_client_message(msg, context.temp_allocator)
  if !ok {
    fmt.eprintln("Failed to encode player input")
    return
  }
  packet := enet.packet_create(raw_data(data), len(data), {})
  enet.peer_send(peer, u8(common.Channels.Default), packet)
}

send_player_message :: proc(peer: ^enet.Peer, message: string) {
  msg: common.Client_To_Server_Message = common.Chat_Message {
    i = slot_id,
    m = message,
  }
  data, ok := common.encode_client_message(msg, context.temp_allocator)
  if !ok {
    fmt.eprintln("Failed to encode chat message")
    return
  }
  packet := enet.packet_create(raw_data(data), len(data), {.RELIABLE})
  enet.peer_send(peer, u8(common.Channels.Reliable), packet)
}

disconnected :: proc(state: ^GameState, host: ^enet.Host, addr: ^enet.Address) {
  rl.BeginDrawing()
  rl.ClearBackground({18, 18, 18, 255})
  rl.DrawText("Press C to connect to the server", 0, 0, 20, rl.WHITE)
  rl.EndDrawing()

  if rl.IsKeyPressed(.C) {
    // Try to reconnect
    peer = enet.host_connect(host, addr, 3, 0)
    if peer != nil {
      state^ = .Connecting
    } else {
      fmt.println("Failed to reconnect")
    }
  }
}

connecting :: proc() {
  rl.BeginDrawing()
  rl.ClearBackground({18, 18, 18, 255})
  rl.DrawText("Connecting to server...", 0, 0, 20, rl.WHITE)
  rl.EndDrawing()
}

connected :: proc() {
  rl.BeginDrawing()
  rl.ClearBackground({18, 18, 18, 255})
  rl.DrawText("> Press B to leave the server", 0, 0, 20, rl.WHITE)
  rl.DrawText("> Use WASD to move around", 0, 20, 20, rl.WHITE)

  PLAYER_SIZE: f32 = 20.0
  half_size := PLAYER_SIZE / 2

  for slot in world.player_slots {
    #partial switch p in slot {
    case common.Player:
      rl.DrawRectanglePro(
        rl.Rectangle{p.position.x, p.position.y, PLAYER_SIZE, PLAYER_SIZE},
        {half_size, half_size},
        0,
        p.color,
      )
      rl.DrawRectangleLinesEx(
        rl.Rectangle{p.position.x - half_size, p.position.y - half_size, PLAYER_SIZE, PLAYER_SIZE},
        1,
        rl.WHITE,
      )
    }
  }

  if rl.IsKeyPressed(.B) {
    // Disconnect from server
    if peer != nil {
      enet.peer_disconnect(peer, 0)
      peer = nil
    }
  }
  rl.EndDrawing()
}
