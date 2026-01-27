package client

import shared "../shared"
import "core:fmt"
import "core:strings"
import "core:time"
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
        fmt.printfln("Connection to %s succeed", shared.format_enet_address(address))
    } else {
        enet.peer_reset(peer)
        fmt.printfln("Connection to %s failed", shared.format_enet_address(address))
        return
    }

    rl.InitWindow(800, 600, "Chat client")
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))

    // Initialize GUI
    nickname_builder: strings.Builder
    message_builder: strings.Builder
    strings.builder_init(&nickname_builder, 0, 32) // Reserve space for 32 chars
    strings.builder_init(&message_builder, 0, 256) // Reserve space for 256 chars

    messages: [dynamic]string
    defer delete(messages)

    nickname_active := false
    message_active := false
    show_warning := false
    warning_timer: f32 = 0.0

    // Define UI rectangles
    nickname_rect := rl.Rectangle{50, 50, 400, 40}
    message_rect := rl.Rectangle{50, 120, 600, 40}
    send_button_rect := rl.Rectangle{550, 50, 200, 40}
    chat_history_rect := rl.Rectangle{50, 230, 700, 320}

    quit := false
    for !rl.WindowShouldClose() && !quit {
        // Handle network events
        if enet.host_service(client, &event, 0) > 0 {
            #partial switch event.type {
            case .RECEIVE:
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

        // Handle GUI input
        if rl.IsMouseButtonPressed(.LEFT) {
            mouse_pos := rl.GetMousePosition()

            // Check which text area is clicked
            nickname_active = rl.CheckCollisionPointRec(mouse_pos, nickname_rect)
            message_active = rl.CheckCollisionPointRec(mouse_pos, message_rect)

            // Check if send button is clicked
            if rl.CheckCollisionPointRec(mouse_pos, send_button_rect) {
                // Send message to server
                nickname := strings.to_string(nickname_builder)
                message := strings.to_string(message_builder)

                if len(nickname) == 0 {
                    show_warning = true
                    warning_timer = 2.0 // Show warning for 2 seconds
                } else if len(message) > 0 {
                    // Create message string
                    full_message := fmt.tprintf("%s: %s", nickname, message)

                    // Create and send packet
                    packet := enet.packet_create(
                        raw_data(full_message),
                        len(full_message),
                        {.RELIABLE},
                    )
                    enet.peer_send(peer, 0, packet)

                    // Clear message builder
                    strings.builder_reset(&message_builder)

                    fmt.println("Sent message:", full_message)
                }
            }
        }

        // Handle keyboard input for active text area
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

            // Handle backspace
            if rl.IsKeyPressed(.BACKSPACE) {
                builder: ^strings.Builder
                if nickname_active {
                    builder = &nickname_builder
                } else {
                    builder = &message_builder
                }

                if strings.builder_len(builder^) > 0 {
                    // Remove last character
                    bytes := builder.buf
                    if len(bytes) > 0 {
                        strings.builder_reset(builder)
                        strings.write_bytes(builder, bytes[:len(bytes) - 1])
                    }
                }
            }
        }

        // Update warning timer
        if show_warning {
            warning_timer -= rl.GetFrameTime()
            if warning_timer <= 0 {
                show_warning = false
            }
        }

        // Draw everything
        rl.BeginDrawing()
        rl.ClearBackground({18, 18, 18, 255})

        // Draw labels
        rl.DrawText("Nickname:", i32(nickname_rect.x), i32(nickname_rect.y - 25), 20, rl.WHITE)
        rl.DrawText("Message:", i32(message_rect.x), i32(message_rect.y - 25), 20, rl.WHITE)

        // Draw text areas
        rl.DrawRectangleRec(nickname_rect, {40, 40, 40, 255})
        rl.DrawRectangleRec(message_rect, {40, 40, 40, 255})

        // Draw borders for active/inactive state
        border_color := nickname_active ? rl.BLUE : rl.GRAY
        rl.DrawRectangleLinesEx(nickname_rect, 2, border_color)

        border_color = message_active ? rl.BLUE : rl.GRAY
        rl.DrawRectangleLinesEx(message_rect, 2, border_color)

        // Draw text content
        nickname_text := strings.to_string(nickname_builder)
        message_text := strings.to_string(message_builder)

        // Enable scissor mode for text display to handle long messages
        rl.BeginScissorMode(
            i32(nickname_rect.x),
            i32(nickname_rect.y),
            i32(nickname_rect.width),
            i32(nickname_rect.height),
        )
        rl.DrawText(
            strings.clone_to_cstring(nickname_text),
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
        rl.DrawText(
            strings.clone_to_cstring(message_text),
            i32(message_rect.x + 10),
            i32(message_rect.y + 10),
            20,
            rl.WHITE,
        )
        rl.EndScissorMode()

        // Draw send button
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

        // Draw character counters
        rl.DrawText(
            strings.clone_to_cstring(fmt.tprintf("%d/20", len(nickname_text))),
            i32(nickname_rect.x + nickname_rect.width - 60),
            i32(nickname_rect.y + nickname_rect.height + 5),
            16,
            rl.GRAY,
        )

        rl.DrawText(
            strings.clone_to_cstring(fmt.tprintf("%d/50", len(message_text))),
            i32(message_rect.x + message_rect.width - 60),
            i32(message_rect.y + message_rect.height + 5),
            16,
            rl.GRAY,
        )

        // Draw chat history
        rl.DrawRectangleRec(chat_history_rect, {25, 25, 25, 255})
        rl.DrawRectangleLinesEx(chat_history_rect, 2, rl.GRAY)
        // Draw chat history label
        rl.DrawText(
            "Chat History",
            i32(chat_history_rect.x),
            i32(chat_history_rect.y - 25),
            20,
            rl.WHITE,
        )
        // Draw messages in chat history
        rl.BeginScissorMode(
            i32(chat_history_rect.x),
            i32(chat_history_rect.y),
            i32(chat_history_rect.width),
            i32(chat_history_rect.height),
        )
        y_offset: f32 = 10
        line_height: f32 = 24

        // Draw messages from newest to oldest (from bottom up)
        if len(messages) > 0 {
            start_index := max(0, len(messages) - 12) // Show last 12 messages
            message_y := chat_history_rect.y + chat_history_rect.height - 20

            for i := len(messages) - 1; i >= start_index; i -= 1 {
                msg := messages[i]
                if len(msg) > 0 {
                    // Calculate text position (right-aligned to show newest at bottom)
                    text_y := message_y - (f32(len(messages) - 1 - i) * line_height)

                    // Don't draw if text is above the chat history area
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
            // Show "No messages yet" when chat is empty
            rl.DrawText(
                "No messages yet. Start chatting!",
                i32(chat_history_rect.x + 10),
                i32(chat_history_rect.y + 10),
                18,
                rl.GRAY,
            )
        }

        rl.EndScissorMode()

        // Draw warning if needed
        if show_warning {
            rl.DrawRectangle(50, 350, 500, 40, {255, 50, 50, 200})
            rl.DrawText("Please enter a nickname before sending!", 60, 360, 20, rl.WHITE)
        }

        // Draw connection status
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

    // Cleanup builders
    strings.builder_destroy(&nickname_builder)
    strings.builder_destroy(&message_builder)

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
