package server

import common "../common"
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
    // I use raylib window because I want to see the result of defer common.review_tracking_allocators(&track, &temp_track)
    rl.InitWindow(321, 321, "serv") // And I'm too lazy to handle cross-platform CTRL+C signal
    for !rl.WindowShouldClose() {     // You can just replace this line with `for {`
        rl.BeginDrawing() // and completely comment out
        rl.EndDrawing() // raylib-related lines
        if enet.host_service(server, &event, 0) <= 0 do continue

        #partial switch event.type {
        case .CONNECT:
            // Only the "peer" field of the event structure is valid for this event
            // and contains the newly connected peer.
            fmt.printfln("New client connected from %s", common.format_enet_address(event.peer.address))
        case .RECEIVE:
            // The packet contained in the "packet" field must be destroyed
            // with enet_packet_destroy() when you are done inspecting its contents.
            fmt.printf(
                "A packet of length %d containing %s was received from %s on channel %d.\n",
                event.packet.dataLength,
                event.packet.data,
                common.format_enet_address(event.peer.address),
                event.channelID,
            )
            msg := strings.string_from_ptr(event.packet.data, int(event.packet.dataLength))
            // enet.packet_create() will memcpy the data we provided. (unless .NO_ALLOCATE flag provided)
            // hence it's safe to destroy the event.packet we raw_getting the data from
            // https://github.com/lsalzman/enet/blob/8be2368a8001f28db44e81d5939de5e613025023/packet.c#L41
            packet := enet.packet_create(raw_data(msg), event.packet.dataLength, {.RELIABLE})
            enet.host_broadcast(server, 0, packet)

            enet.packet_destroy(event.packet)
        case .DISCONNECT:
            full_message := fmt.tprintf("USER %s disconnected", common.format_enet_address(event.peer.address))
            // enet.packet_create() will memcpy the data we provided. (unless .NO_ALLOCATE flag provided)
            // hence it's safe to use temporarly allocated `full_message`
            // https://github.com/lsalzman/enet/blob/8be2368a8001f28db44e81d5939de5e613025023/packet.c#L41
            packet := enet.packet_create(raw_data(full_message), len(full_message), {.RELIABLE})
            enet.host_broadcast(server, 0, packet)

            // Only the "peer" field of the event structure is valid for this event
            fmt.printfln("peer %s either explicitly disconnected or timed out", common.format_enet_address(event.peer.address))
            /* Reset the peer's client information. */
            event.peer.data = nil
        }

        free_all(context.temp_allocator)
    }
    rl.CloseWindow()
}
