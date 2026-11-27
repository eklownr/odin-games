package main

import rl "vendor:raylib"


//////////////////////////////////////////
// -- Set new Level --
set_new_level :: proc(g: ^Game, lv: int) {
    level := lv
    if level < 1 || level > LEVEL_COUNT { level = 1 }

    // reset game blocks, Töm den nuvarande listan först
    resize(&g.blocks, 0)
    g.target_speed = 300 // reset ball speed
    g.current_level = level

    // Level 2 får nya slumpmässiga färger varje gång
    if level == 2 {
        for template in g.levels[1] {
            b := template // Kopiera så template-färgerna inte ändras
            b.color = rl.Color{
                u8(rl.GetRandomValue(0, 255)),
                u8(rl.GetRandomValue(0, 255)),
                u8(rl.GetRandomValue(0, 255)),
                255,
            }
            append(&g.blocks, b)
        }
        return
    }

    // Level 1 och 3-9 kopieras direkt från sin mall
    for b in g.levels[level-1] {
        append(&g.blocks, b)
    }
}


// -- reset ball --
reset_ball :: proc(g: ^Game) {

    g.ball_pos.y = f32(SCREEN_HEIGHT) / 2.0
    g.ball_pos.x = f32(SCREEN_WIDTH) / 2.0
    g.ball_speed_x = 0.0      // Starta utan sidledshastighet
    g.ball_speed_y = 300.0
}
