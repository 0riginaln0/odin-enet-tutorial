package client

import "../shared"
import "core:fmt"
import "core:mem"
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

}
