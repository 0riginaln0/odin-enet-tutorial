package server

import shared "../shared"
import "core:fmt"
import "core:mem"
import "core:strings"
import enet "vendor:ENet"
import rl "vendor:raylib"

main :: proc() {
    track: mem.Tracking_Allocator; mem.tracking_allocator_init(&track, context.allocator)
    temp_track: mem.Tracking_Allocator; mem.tracking_allocator_init(&temp_track, context.temp_allocator)
    context.allocator = mem.tracking_allocator(&track)
    context.temp_allocator = mem.tracking_allocator(&temp_track)
    defer shared.review_tracking_allocators(&track, &temp_track)

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

    rl.InitWindow(321, 321, "serv")
    event: enet.Event
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.EndDrawing()
        if enet.host_service(server, &event, 0) <= 0 do continue

        #partial switch event.type {
        case .CONNECT:
            // Only the "peer" field of the event structure is valid for this event
            // and contains the newly connected peer.
            fmt.printfln(
                "New client connected from %s",
                shared.format_enet_address(event.peer.address),
            )
        case .RECEIVE:
            // The packet contained in the "packet" field must be destroyed
            // with enet_packet_destroy() when you are done inspecting its contents.
            fmt.printf(
                "A packet of length %d containing %s was received from %s on channel %d.\n",
                event.packet.dataLength,
                event.packet.data,
                shared.format_enet_address(event.peer.address),
                event.channelID,
            )
            msg := strings.string_from_ptr(event.packet.data, int(event.packet.dataLength))
            packet := enet.packet_create(raw_data(msg), event.packet.dataLength, {.RELIABLE})
            enet.host_broadcast(server, 0, packet)

            enet.packet_destroy(event.packet)
        case .DISCONNECT:
            // Only the "peer" field of the event structure is valid for this event
            fmt.printfln(
                "peer %s either explicitly disconnected or timed out",
                shared.format_enet_address(event.peer.address),
            )
            /* Reset the peer's client information. */
            event.peer.data = nil
        }

        free_all(context.temp_allocator)
    }
    rl.CloseWindow()
}
