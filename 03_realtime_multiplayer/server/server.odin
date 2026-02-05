package server

import shared "../shared"
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
    buttons:  bit_set[Buttons],
    peer:     ^enet.Peer,
}

Server_To_Client_Message :: union {
    World_Update,
}
World_Update :: World

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
Slot_Assignment :: struct {
    index: u8,
}

Buttons :: enum {
    Up,
    Down,
    Left,
    Right,
}

Channels :: enum u8 {
    Default,
    Reliable,
}

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
    event: enet.Event

    /*
        A good way is;
        Fixed tick rate
        But accumulate time and only tick as many frames as time has actually been accumulated
    */
    TICK_RATE :: 100 // Frequency in Hertz at which a game server updates the game state
    DT :: 1 * time.Second / TICK_RATE
    fmt.println(DT)
    tick := time.tick_now()
    accumulator: time.Duration = DT

    world: World
    for {
        // Handle inputs
        handle_incoming_events(server, &world, &event)

        for ; accumulator >= DT; accumulator -= DT {
            world_update(&world)

            // Send updated world to connected peers
        }

        time_passed_since_last_tick := time.tick_lap_time(&tick)
        accumulator += time_passed_since_last_tick
    }
}

find_free_slot :: proc(world: ^World) -> (u8, bool) {
    for slot, i in world.player_slots {
        if _, is_free_slot := slot.(Free); is_free_slot do return u8(i), true
    }
    return 0, false
}

handle_incoming_events :: proc(server: ^enet.Host, world: ^World, event: ^enet.Event) {
    if enet.host_service(server, event, 0) <= 0 do return

    #partial switch event.type {
    case .CONNECT:
        // Only the "peer" field of the event structure is valid for this event
        // and contains the newly connected peer.
        fmt.printfln(
            "New client connected from %s",
            shared.format_enet_address(event.peer.address),
        )
        if slot_id, found := find_free_slot(world); found {
            packet := enet.packet_create(&slot_id, size_of(u8), {})
            enet.peer_send(event.peer, u8(Channels.Reliable), packet)
        } else {
            enet.peer_disconnect_now(event.peer, 1)
        }
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
        // enet.packet_create() will memcpy the data we provided. (unless .NO_ALLOCATE flag provided)
        // hence it's safe to destroy the event.packet we raw_getting the data from
        // https://github.com/lsalzman/enet/blob/8be2368a8001f28db44e81d5939de5e613025023/packet.c#L41
        packet := enet.packet_create(raw_data(msg), event.packet.dataLength, {.RELIABLE})
        enet.host_broadcast(server, 0, packet)

        enet.packet_destroy(event.packet)
    case .DISCONNECT:
        for &slot in world.player_slots {
            if player, found := slot.(Player); found && player.peer == event.peer {
                slot = Free{}
                break
            }
        }
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

world_update :: proc(world: ^World) {
    for player_slot in world.player_slots {
        player := player_slot.(Player) or_continue

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
