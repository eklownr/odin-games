package main

import rl "vendor:raylib"
//import la "core:math/linalg"

main :: proc() {
    // Initiera fönster
    rl.InitWindow(800, 600, "Odin Hello World")
    defer rl.CloseWindow()

    // Spelarens position (x, y)
    pos: [2]f32 = {350, 550}
    speed: f32 = 500.0

    // globals
    should_close: bool = false
    pos_ball: [2]f32 = {350, 550}

    // Spelloop
    for !rl.WindowShouldClose() && !should_close {
        dt := rl.GetFrameTime() // Tid sedan förra bilden (för jämn rörelse)

        // Sätt bara flaggan, stäng INTE fönstret här!
        if rl.IsKeyDown(.Q) {
            should_close = true
        }

        // Hantera input
        if rl.IsKeyDown(.RIGHT) { pos.x += speed * dt }
        if rl.IsKeyDown(.LEFT)  { pos.x -= speed * dt }

        // Rita
        rl.BeginDrawing()
        rl.ClearBackground({40, 40, 80, 255}) // Mörkblå bakgrund
        
        // Rita en röd fyrkant vid spelarens position
        rl.DrawRectangleV(pos, {150, 20}, rl.RED)
        
        rl.DrawText("Brakout by eklow, Odin first game!", 10, 10, 20, rl.WHITE)
        rl.EndDrawing()
    }
    // När loopen bryts, avslutas main(), och 'defer rl.CloseWindow()' körs säkert.
}
