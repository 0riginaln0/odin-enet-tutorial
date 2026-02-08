package client

import "core:fmt"
import "core:mem"
import enet "vendor:ENet"
import rl "vendor:raylib"

import common "../common"

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
    client: ^enet.Host = enet.host_create(nil, 1, CHANNEL_LIMIT, 0, 0)
    if client == nil {
        fmt.println("An error occured while trying to create an ENet host")
        return
    }
    defer enet.host_destroy(client)

    address: enet.Address
    enet.address_set_host(&address, "127.0.0.1")
    address.port = 27585

    peer: ^enet.Peer = enet.host_connect(client, &address, CHANNEL_LIMIT, 0)
    if peer == nil {
        fmt.println("Failed to initiate a connection to a foreign host")
        return
    }

    rl.InitWindow(800, 600, "Chat client")
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
    quit := false

    input := common.Player_Input{}

    state := State.Disconnected
    for !rl.WindowShouldClose() && !quit {

        switch state {
        case .Disconnected:
            disconnected(&state)
        case .Connected:
            connected(&state, &input)
        }
    }
}

State :: enum {
    Disconnected,
    Connected,
}

disconnected :: proc(state: ^State) {
    rl.BeginDrawing()
    rl.ClearBackground({18, 18, 18, 255})

    rl.DrawText("Press C to connect to the server", 0, 0, 20, rl.WHITE)
    rl.EndDrawing()
}

connected :: proc(state: ^State, input: ^common.Player_Input) {
    input.buttons = {}
    if rl.IsKeyDown(.W) do input.buttons += {.Up}
    if rl.IsKeyDown(.S) do input.buttons += {.Down}
    if rl.IsKeyDown(.A) do input.buttons += {.Left}
    if rl.IsKeyDown(.D) do input.buttons += {.Right}

    rl.BeginDrawing()
    rl.ClearBackground({18, 18, 18, 255})
    rl.DrawText("Press B to leave the server", 0, 0, 20, rl.WHITE)
    rl.EndDrawing()
}
