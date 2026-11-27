package main

import rl "vendor:raylib"
import "core:fmt"


/////////////////////////////////////////////
// 3. Main (Initiering & Loop)
main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Odin Breakout")
    defer rl.CloseWindow()

    bg_texture := rl.LoadTexture("bg.gif")
    // Kontrollera att bilden laddades korrekt
    if bg_texture.id == 0 {
        fmt.println("Fel: Kunde inte ladda bakgrundsbilden!")
        return
    }
    defer rl.UnloadTexture(bg_texture)

    // Initiera ljudsystemet
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice() // Stäng ljudet när programmet avslutas
    
    // Initiera spelstaten
    game: Game = {
        ball_pos     = { f32(SCREEN_WIDTH)/2.0,  f32(SCREEN_HEIGHT)/2.0},
        ball_speed_x = 0.0,
        ball_speed_y = 300.0,
        target_speed = 300.0,
        paddle_x     = f32(SCREEN_WIDTH)/2.0 - PADDLE_WIDTH/2.0,
        paddle_y     = f32(SCREEN_HEIGHT) - 40.0,
        paddle_speed = 500.0,
        blip_low    = rl.LoadSound("blip.wav"),
        blip_mid    = rl.LoadSound("blip.wav"),
        blip_high   = rl.LoadSound("blip.wav"),
        blip_high2  = rl.LoadSound("blip.wav"),
        bg_image    = bg_texture,
        current_level = 1,
    }

    defer rl.UnloadSound(game.blip_low)
    defer rl.UnloadSound(game.blip_mid)
    defer rl.UnloadSound(game.blip_high)
    defer rl.UnloadSound(game.blip_high2)

    // Sätt pitchen EN gång vid start:
    rl.SetSoundPitch(game.blip_low, 0.8)
    rl.SetSoundPitch(game.blip_mid, 1.0)
    rl.SetSoundPitch(game.blip_high, 1.5)
    rl.SetSoundPitch(game.blip_high2, 2.0)

    // Lägg till 7 block per rad, med olika färger
    for i in 0..<28 {
        row := i / 7
        col := i % 7

        block := Block{
            pos    = {50.0 + f32(i) * 102.0, 50.0},
            size   = {90.0, 30.0},
            active = true,
            color  = rl.YELLOW,
        }
        if i+1 > 7{
            block.pos = {50.0 + f32(i-7) * 102.0, 100.0}
            block.color = rl.BLUE
        }
        if i+1 > 14{
            block.pos = {50.0 + f32(i-14) * 102.0, 150.0}
            block.color = rl.PURPLE
        }
        if i+1 > 21{
            block.pos = {50.0 + f32(i-21) * 102.0, 200.0}
            block.color = rl.RED
        }

        // Level 1: ta bort block för att göra en triangel
        if !(i==7 || i==13 || i==14 || i==15 || i==19 || i==20 || i==21 || i==22 || i==23 || i==25 || i==26 || i==27) {
            append(&game.blocks_level_1, block)
            append(&game.blocks, block) // Starta på level 1
        }

        // Level 2: alla block (färgerna slumpas i set_new_level)
        append(&game.blocks_level_2, block)

        // Level 3: schackmönster i grönt och orange
        block3 := block
        if (row + col) % 2 == 0 {
            block3.color = rl.GREEN
        } else {
            block3.color = rl.ORANGE
        }
        append(&game.blocks_level_3, block3)
    }


    // Sett flagga: avsluta game loop
    should_close: bool = false

    for !rl.WindowShouldClose() && !should_close {
        dt := rl.GetFrameTime()
        
        update_game(&game, dt) // Uppdatera logik
        draw_game(&game)       // Rita grafik
        
        if rl.IsKeyDown(.Q) { should_close = true } // Stäng ner med q
    }
}   
