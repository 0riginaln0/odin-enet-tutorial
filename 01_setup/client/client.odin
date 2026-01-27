package client

import shared "../shared"
import "core:fmt"
import enet "vendor:ENet"
import rl "vendor:raylib"

main :: proc() {
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

    event: enet.Event
    if enet.host_service(client, &event, 5000) > 0 && event.type == .CONNECT {
        // Only the "peer" field of the event structure is valid for this event
        // and contains the newly connected peer.
        fmt.printfln("Connection to %s succeed", shared.format_enet_address(address))
    } else {
        enet.peer_reset(peer)
        fmt.println("Connection to %s failed", shared.format_enet_address(address))
        return
    }

    rl.InitWindow(500, 500, "Chat client")
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
    quit := false
    for !rl.WindowShouldClose() && !quit {
        if enet.host_service(client, &event, 0) > 0 {
            #partial switch event.type {
            case .RECEIVE:
                // The packet contained in the "packet" field must be destroyed
                // with enet_packet_destroy() when you are done inspecting its contents.
                fmt.printf(
                    "A packet of length %d containing %s was received from %s on channel %d.\n",
                    event.packet.dataLength,
                    event.packet.data,
                    event.peer.data,
                    event.channelID,
                )
                enet.packet_destroy(event.packet)
            }
        }

        if rl.IsKeyPressed(.D) {
            fmt.println("au go bb")
            disconnect_from_server(client, peer, &event)
            quit = true
        }

        rl.BeginDrawing()
        rl.ClearBackground({18, 18, 18, 255})
        rl.DrawText("Press D to disconnect", 190, 200, 20, rl.WHITE)
        rl.EndDrawing()
        free_all(context.temp_allocator)
    }
    rl.CloseWindow()

}

disconnect_from_server :: proc(my_host: ^enet.Host, server_peer: ^enet.Peer, event: ^enet.Event) {
    enet.peer_disconnect(server_peer, 0)
    for enet.host_service(my_host, event, 3000) > 0 {
        #partial switch event.type {
        case .RECEIVE:
            enet.packet_destroy(event.packet)
        case .DISCONNECT:
            fmt.println("Disconnection succeeded")
            return
        }
    }
}
