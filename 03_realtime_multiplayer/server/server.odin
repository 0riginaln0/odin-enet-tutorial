package server

import "core:fmt"
import "core:time"
import rl "vendor:raylib"

World :: struct {
    players: [3]Player_Slot,
}

Player_Slot :: union {
    Free,
    Player,
}
Free :: struct {}
Player :: struct {
    color:    rl.Color,
    position: rl.Vector2,
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

Buttons :: enum {
    Up,
    Down,
    Left,
    Right,
}

main :: proc() {
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
    players_inputs: [dynamic]Player_Input
    for {
        for ; accumulator >= DT; accumulator -= DT {
            // *tick* the world
            world_update(
                &world,
                /*Player's input gathered from network*/
            )
        }

        time_passed_since_last_tick := time.tick_lap_time(&tick)
        accumulator += time_passed_since_last_tick
    }
}

world_update :: proc(world: ^World) {

}
