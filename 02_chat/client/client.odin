package client

import shared "../shared"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:time"
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

    peer: ^enet.Peer = enet.host_connect(client, &address, CHANNEL_LIMIT, 0)
    if peer == nil {
        fmt.println("Failed to initiate a connection to a foreign host")
        return
    }

    event: enet.Event
    if enet.host_service(client, &event, 5000) > 0 && event.type == .CONNECT {
        fmt.printfln("Connection to %s succeed", shared.format_enet_address(address))
    } else {
        enet.peer_reset(peer)
        fmt.printfln("Connection to %s failed", shared.format_enet_address(address))
        return
    }

    rl.InitWindow(800, 600, "Chat client")
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))

    nickname_builder: strings.Builder
    message_builder: strings.Builder
    strings.builder_init(&nickname_builder, 0, 32)
    strings.builder_init(&message_builder, 0, 256)
    defer {
        strings.builder_destroy(&nickname_builder)
        strings.builder_destroy(&message_builder)
    }
    messages: [dynamic]string
    defer {
        for msg in messages {
            delete(msg)
        }
        delete(messages)
    }

    nickname_active := false
    message_active := false
    show_warning := false
    warning_timer: f32 = 0.0

    nickname_rect := rl.Rectangle{50, 50, 400, 40}
    message_rect := rl.Rectangle{50, 120, 600, 40}
    send_button_rect := rl.Rectangle{550, 50, 200, 40}
    chat_history_rect := rl.Rectangle{50, 230, 700, 320}

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
                    shared.format_enet_address(event.peer.address),
                    event.channelID,
                )
                msg := strings.clone(
                    strings.string_from_ptr(event.packet.data, int(event.packet.dataLength)),
                )
                append(&messages, msg)
                enet.packet_destroy(event.packet)
            case .DISCONNECT:
                fmt.println("Disconnected from server")
                quit = true
            }
        }

        if rl.IsMouseButtonPressed(.LEFT) {
            mouse_pos := rl.GetMousePosition()

            nickname_active = rl.CheckCollisionPointRec(mouse_pos, nickname_rect)
            message_active = rl.CheckCollisionPointRec(mouse_pos, message_rect)

            if rl.CheckCollisionPointRec(mouse_pos, send_button_rect) {
                nickname := strings.to_string(nickname_builder)
                message := strings.to_string(message_builder)

                if len(nickname) == 0 {
                    show_warning = true
                    warning_timer = 2.0
                } else if len(message) > 0 {
                    full_message := fmt.tprintf("%s: %s", nickname, message)
                    packet := enet.packet_create(
                        raw_data(full_message),
                        len(full_message),
                        {.RELIABLE},
                    )
                    enet.peer_send(peer, 0, packet)
                    strings.builder_reset(&message_builder)
                    fmt.println("Sent message:", full_message)
                }
            }
        }

        if nickname_active || message_active {
            key := rl.GetCharPressed()
            for key > 0 {
                // Only accept ASCII characters (0-127)
                if key <= 127 {
                    builder: ^strings.Builder
                    max_len: int

                    if nickname_active {
                        builder = &nickname_builder
                        max_len = 20
                    } else {
                        builder = &message_builder
                        max_len = 50
                    }

                    // Check if we haven't reached the max length
                    if strings.builder_len(builder^) < max_len {
                        strings.write_rune(builder, rune(key))
                    }
                }
                key = rl.GetCharPressed()
            }

            if rl.IsKeyPressed(.BACKSPACE) {
                builder: ^strings.Builder
                if nickname_active {
                    builder = &nickname_builder
                } else {
                    builder = &message_builder
                }

                if strings.builder_len(builder^) > 0 {
                    bytes := builder.buf
                    if len(bytes) > 0 {
                        strings.builder_reset(builder)
                        strings.write_bytes(builder, bytes[:len(bytes) - 1])
                    }
                }
            }
        }

        if show_warning {
            warning_timer -= rl.GetFrameTime()
            if warning_timer <= 0 {
                show_warning = false
            }
        }

        rl.BeginDrawing()
        rl.ClearBackground({18, 18, 18, 255})

        rl.DrawText("Nickname:", i32(nickname_rect.x), i32(nickname_rect.y - 25), 20, rl.WHITE)
        rl.DrawText("Message:", i32(message_rect.x), i32(message_rect.y - 25), 20, rl.WHITE)

        rl.DrawRectangleRec(nickname_rect, {40, 40, 40, 255})
        rl.DrawRectangleRec(message_rect, {40, 40, 40, 255})

        border_color := nickname_active ? rl.BLUE : rl.GRAY
        rl.DrawRectangleLinesEx(nickname_rect, 2, border_color)

        border_color = message_active ? rl.BLUE : rl.GRAY
        rl.DrawRectangleLinesEx(message_rect, 2, border_color)

        nickname_text := strings.to_string(nickname_builder)
        message_text := strings.to_string(message_builder)
        nickname_cstr := strings.clone_to_cstring(nickname_text, context.temp_allocator)
        message_cstr := strings.clone_to_cstring(message_text, context.temp_allocator)

        rl.BeginScissorMode(
            i32(nickname_rect.x),
            i32(nickname_rect.y),
            i32(nickname_rect.width),
            i32(nickname_rect.height),
        )
        rl.DrawText(
            nickname_cstr,
            i32(nickname_rect.x + 10),
            i32(nickname_rect.y + 10),
            20,
            rl.WHITE,
        )
        rl.EndScissorMode()

        rl.BeginScissorMode(
            i32(message_rect.x),
            i32(message_rect.y),
            i32(message_rect.width),
            i32(message_rect.height),
        )
        rl.DrawText(message_cstr, i32(message_rect.x + 10), i32(message_rect.y + 10), 20, rl.WHITE)
        rl.EndScissorMode()

        button_color := rl.Color{80, 80, 80, 255}
        if rl.CheckCollisionPointRec(rl.GetMousePosition(), send_button_rect) {
            button_color = {100, 100, 100, 255}
        }
        rl.DrawRectangleRec(send_button_rect, button_color)
        rl.DrawText(
            "Send Message",
            i32(send_button_rect.x + 20),
            i32(send_button_rect.y + 10),
            20,
            rl.WHITE,
        )

        nickname_counter := fmt.tprintf("%d/20", len(nickname_text))
        message_counter := fmt.tprintf("%d/50", len(message_text))
        nickname_counter_cstr := strings.clone_to_cstring(nickname_counter, context.temp_allocator)
        message_counter_cstr := strings.clone_to_cstring(message_counter, context.temp_allocator)
        rl.DrawText(
            nickname_counter_cstr,
            i32(nickname_rect.x + nickname_rect.width - 60),
            i32(nickname_rect.y + nickname_rect.height + 5),
            16,
            rl.GRAY,
        )

        rl.DrawText(
            message_counter_cstr,
            i32(message_rect.x + message_rect.width - 60),
            i32(message_rect.y + message_rect.height + 5),
            16,
            rl.GRAY,
        )

        rl.DrawRectangleRec(chat_history_rect, {25, 25, 25, 255})
        rl.DrawRectangleLinesEx(chat_history_rect, 2, rl.GRAY)

        rl.DrawText(
            "Chat History",
            i32(chat_history_rect.x),
            i32(chat_history_rect.y - 25),
            20,
            rl.WHITE,
        )

        rl.BeginScissorMode(
            i32(chat_history_rect.x),
            i32(chat_history_rect.y),
            i32(chat_history_rect.width),
            i32(chat_history_rect.height),
        )
        y_offset: f32 = 10
        line_height: f32 = 24

        if len(messages) > 0 {
            start_index := max(0, len(messages) - 12)
            message_y := chat_history_rect.y + chat_history_rect.height - 20

            for i := len(messages) - 1; i >= start_index; i -= 1 {
                msg := messages[i]
                if len(msg) > 0 {

                    text_y := message_y - (f32(len(messages) - 1 - i) * line_height)

                    if text_y >= chat_history_rect.y {
                        rl.DrawText(
                            strings.clone_to_cstring(msg),
                            i32(chat_history_rect.x + 10),
                            i32(text_y),
                            18,
                            rl.WHITE,
                        )
                    }
                }
            }
        } else {
            rl.DrawText(
                "No messages yet. Start chatting!",
                i32(chat_history_rect.x + 10),
                i32(chat_history_rect.y + 10),
                18,
                rl.GRAY,
            )
        }

        rl.EndScissorMode()

        if show_warning {
            rl.DrawRectangle(50, 350, 500, 40, {255, 50, 50, 200})
            rl.DrawText("Please enter a nickname before sending!", 60, 360, 20, rl.WHITE)
        }

        rl.DrawText(
            strings.clone_to_cstring(
                fmt.tprintf("Connected to: %s", shared.format_enet_address(address)),
            ),
            400,
            550,
            16,
            rl.GREEN,
        )

        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    disconnect_from_server(client, peer, &event)
    rl.CloseWindow()
}

disconnect_from_server :: proc(my_host: ^enet.Host, server_peer: ^enet.Peer, event: ^enet.Event) {
    enet.peer_disconnect(server_peer, 0)
    WAITING_FOR :: 3 * time.Second
    started_waiting := time.tick_now()
    remaining := (WAITING_FOR - time.tick_since(started_waiting))
    for remaining > 0 {
        if enet.host_service(my_host, event, u32(remaining / time.Millisecond)) > 0 {
            #partial switch event.type {
            case .RECEIVE:
                enet.packet_destroy(event.packet)
            case .DISCONNECT:
                fmt.println("Disconnection succeeded")
                return
            }
        }
        remaining = (WAITING_FOR - time.tick_since(started_waiting))
    }
    enet.peer_reset(server_peer)
}
