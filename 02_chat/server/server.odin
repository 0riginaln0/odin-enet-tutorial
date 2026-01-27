package server

import shared "../shared"
import "core:fmt"
import enet "vendor:ENet"

main :: proc() {
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
    for {
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
            enet.host_broadcast(server, 0, event.packet)
        // enet.packet_destroy(event.packet)
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
}
