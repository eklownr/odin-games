package main

import rl "vendor:raylib"


/////////////////////////////////////////////
// 3. Main (Initiering & Loop)
main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Odin Breakout")
    defer rl.CloseWindow()

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
        current_level = 2, // Start i mitten av bottenraden

        state            = .PLAY,
        transition_timer = 0,
        pending_level    = 1,
        tube_center      = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0},
        transition_from  = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0},
        tube_start       = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0},
        tube_exit_pos    = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0},
        tube_dir         = .UP,
        tube_flash       = 0,
        camera = rl.Camera2D{
            offset   = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0},
            target   = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0},
            rotation = 0,
            zoom     = 1,
        },
    }

    defer rl.UnloadSound(game.blip_low)
    defer rl.UnloadSound(game.blip_mid)
    defer rl.UnloadSound(game.blip_high)
    defer rl.UnloadSound(game.blip_high2)
    defer unload_blip_pool(&game) // Måste städas innan original-ljudet

    // Sätt pitchen EN gång vid start:
    rl.SetSoundPitch(game.blip_low, 0.8)
    rl.SetSoundPitch(game.blip_mid, 1.0)
    rl.SetSoundPitch(game.blip_high, 1.5)
    rl.SetSoundPitch(game.blip_high2, 2.0)

    init_blip_pool(&game)

    // Bygg mallarna för alla 9 levels (4 rader x 7 kolumner)
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

        // Level 1: triangel (som tidigare)
        if !(i==7 || i==13 || i==14 || i==15 || i==19 || i==20 || i==21 || i==22 || i==23 || i==25 || i==26 || i==27) {
            append(&game.levels[0], block)
        }

        // Level 2: alla block (färgerna slumpas i set_new_level)
        append(&game.levels[1], block)

        // Level 3: schackmönster i grönt och orange (som tidigare)
        block3 := block
        if (row + col) % 2 == 0 {
            block3.color = rl.GREEN
        } else {
            block3.color = rl.ORANGE
        }
        append(&game.levels[2], block3)

        // Level 4: vertikala ränder i skyblue/magenta
        block4 := block
        if col % 2 == 0 {
            block4.color = rl.SKYBLUE
        } else {
            block4.color = rl.MAGENTA
        }
        append(&game.levels[3], block4)

        // Level 5: diagonala band i guld/violett/lime
        block5 := block
        switch (row + col) % 3 {
            case 0: block5.color = rl.GOLD
            case 1: block5.color = rl.VIOLET
            case 2: block5.color = rl.LIME
        }
        append(&game.levels[4], block5)

        // Level 6: var tredje kolumn, färg per rad
        if col % 3 == 0 {
            block6 := block
            switch row {
                case 0: block6.color = rl.GOLD
                case 1: block6.color = rl.PINK
                case 2: block6.color = rl.SKYBLUE
                case 3: block6.color = rl.GREEN
            }
            append(&game.levels[5], block6)
        }

        // Level 7: omvänd triangel (1, 3, 5, 7 block)
        if col >= 3 - row && col <= 3 + row {
            block7 := block
            switch row {
                case 0: block7.color = rl.GOLD
                case 1: block7.color = rl.PINK
                case 2: block7.color = rl.VIOLET
                case 3: block7.color = rl.LIME
            }
            append(&game.levels[6], block7)
        }

        // Level 8: färgsekvens guld/magenta/lime/skyblue
        block8 := block
        switch i % 4 {
            case 0: block8.color = rl.GOLD
            case 1: block8.color = rl.MAGENTA
            case 2: block8.color = rl.LIME
            case 3: block8.color = rl.SKYBLUE
        }
        append(&game.levels[7], block8)

        // Level 9: ram runt banan
        if row == 0 || row == 3 || col == 0 || col == 6 {
            block9 := block
            if row == 0 || row == 3 {
                block9.color = rl.GOLD
            } else {
                block9.color = rl.VIOLET
            }
            append(&game.levels[8], block9)
        }
    }

    // Starta på level 2
    for b in game.levels[1] {
        append(&game.blocks, b)
    }

    // TILLFÄLLIGT TEST: bara ett block i mitten på alla levels
    if TEST_SINGLE_BLOCK {
        center_block := Block{
            pos    = {f32(SCREEN_WIDTH)/2.0 - 45.0, 100.0},
            size   = {90.0, 30.0},
            active = true,
            color  = rl.YELLOW,
        }
        for i in 0..<LEVEL_COUNT {
            resize(&game.levels[i], 0)
            append(&game.levels[i], center_block)
        }
        resize(&game.blocks, 0)
        append(&game.blocks, center_block)
    }

    // Portaler är alltid öppna – de är enda sättet att byta level
    spawn_portals(&game)


    // Sett flagga: avsluta game loop
    should_close: bool = false

    for !rl.WindowShouldClose() && !should_close {
        dt := rl.GetFrameTime()
        
        update_game(&game, dt) // Uppdatera logik
        draw_game(&game)       // Rita grafik
        
        if rl.IsKeyDown(.Q) { should_close = true } // Stäng ner med q
    }
}   
