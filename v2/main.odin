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
        current_room = 2, // Start i mitten av bottenraden

        state            = .PLAY,
        transition_timer = 0,
        pending_room     = 1,
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
        has_key           = false,
        box_unlocked      = false,
        won               = false,
        missing_key_timer = 0,
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

    // Bygg mallarna för alla 9 rum (4 rader x 7 kolumner)
    for i in 0..<28 {
        row := i / 7
        col := i % 7

        block := Block{
            pos    = {50.0 + f32(i) * 102.0, 50.0},
            size   = BLOCK_SIZE,
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

        // Rum 1: triangel (som tidigare)
        if !(i==7 || i==13 || i==14 || i==15 || i==19 || i==20 || i==21 || i==22 || i==23 || i==25 || i==26 || i==27) {
            append(&game.rooms[0], block)
        }

        // Rum 2: pil upp
        arrow := (row == 0 && col == 3) ||
                 (row == 1 && col >= 2 && col <= 4) ||
                 (row == 2 && col >= 1 && col <= 5) ||
                 (row == 3 && col == 3)
        if arrow {
            append(&game.rooms[1], block) // Färgerna slumpas i set_new_room
        }

        // Rum 3: schackmönster i grönt och orange (som tidigare)
        block3 := block
        if (row + col) % 2 == 0 {
            block3.color = rl.GREEN
        } else {
            block3.color = rl.ORANGE
        }
        append(&game.rooms[2], block3)

        // Rum 4: glesare vertikala ränder i skyblue/magenta
        if row == 0 || row == 2 {
            block4 := block
            if col % 2 == 0 {
                block4.color = rl.SKYBLUE
            } else {
                block4.color = rl.MAGENTA
            }
            append(&game.rooms[3], block4)
        }

        // Rum 5: diagonala band i guld/violett, ett band borttaget
        if (row + col) % 3 != 2 {
            block5 := block
            switch (row + col) % 3 {
                case 0: block5.color = rl.GOLD
                case 1: block5.color = rl.VIOLET
                case:   // 2 används inte
            }
            append(&game.rooms[4], block5)
        }

        // Rum 6: var tredje kolumn, färg per rad
        if col % 3 == 0 {
            block6 := block
            switch row {
                case 0: block6.color = rl.GOLD
                case 1: block6.color = rl.PINK
                case 2: block6.color = rl.SKYBLUE
                case 3: block6.color = rl.GREEN
            }
            append(&game.rooms[5], block6)
        }

        // Rum 8: färgsekvens guld/magenta/lime/skyblue, vartannat block
        if i % 2 == 0 {
            block8 := block
            switch i % 4 {
                case 0: block8.color = rl.GOLD
                case 1: block8.color = rl.MAGENTA
                case 2: block8.color = rl.LIME
                case 3: block8.color = rl.SKYBLUE
            }
            append(&game.rooms[7], block8)
        }
    }

    // Rum 7: tio block i en diamant (ruter) runt nyckeln, nu med samma
    // storlek som blocken i övriga rum. Mitten hålls tom så nyckeln i
    // KEY_RECT inte täcks av något block.
    resize(&game.rooms[6], 0)
    diamond_positions := [10]rl.Vector2{
        {355.0, 60.0},                                      // toppen
        {245.0, 110.0}, {465.0, 110.0},                     // 2
        {135.0, 160.0}, {355.0, 160.0}, {575.0, 160.0},     // 3
        {135.0, 270.0}, {355.0, 270.0}, {575.0, 270.0},     // 3 (nyckeln i mitten)
        {355.0, 320.0},                                     // botten
    }
    for i in 0..<10 {
        block_color := rl.GOLD
        if i % 2 == 1 { block_color = rl.VIOLET }
        append(&game.rooms[6], Block{
            pos    = diamond_positions[i],
            size   = BLOCK_SIZE,
            active = true,
            color  = block_color,
        })
    }

    // Rum 9: kistan omges av en öppen blockram (glapp nedåt mot bollen).
    // Blocken har samma storlek som i övriga rum och inget täcker
    // BOX_RECT eller nyckelhålet.
    resize(&game.rooms[8], 0)
    chest_ring := [11]rl.Vector2{
        {250.0, 50.0},  {355.0, 50.0},  {460.0, 50.0},
        {200.0, 100.0}, {200.0, 150.0}, {200.0, 200.0},
        {510.0, 100.0}, {510.0, 150.0}, {510.0, 200.0},
        {250.0, 250.0}, {460.0, 250.0},
    }
    for i in 0..<11 {
        block_color := rl.GOLD
        if i % 2 == 1 { block_color = rl.VIOLET }
        append(&game.rooms[8], Block{
            pos    = chest_ring[i],
            size   = BLOCK_SIZE,
            active = true,
            color  = block_color,
        })
    }

    // Starta på rum 2
    for b in game.rooms[1] {
        append(&game.blocks, b)
    }

    // Portaler är alltid öppna – de är enda sättet att byta rum
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
