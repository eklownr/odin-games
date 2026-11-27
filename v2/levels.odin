package main

import rl "vendor:raylib"


//////////////////////////////////////////
// -- Set new Level --
set_new_level :: proc(g: ^Game, lv: int) {
    // reset game blocks, Töm den nuvarande listan först
    resize(&g.blocks, 0)
    g.target_speed = 300 // reset ball speed
    g.current_level = lv

    switch lv {
        case 1:
            for b in g.blocks_level_1 {
                append(&g.blocks, b)
            }
        case 2:
            for template in g.blocks_level_2 {
                b := template // Kopiera så template-färgerna inte ändras
                // Generera slumpmässiga R, G, B värden (0-255)
                r_val := u8(rl.GetRandomValue(0, 255))
                g_val := u8(rl.GetRandomValue(0, 255))
                b_val := u8(rl.GetRandomValue(0, 255))
            
                // Sätt färgen manuellt (Alpha sätts till 255 för heltäckande)
                b.color = rl.Color{r_val, g_val, b_val, 255}
            
                append(&g.blocks, b)
            }
        case 3:
            for b in g.blocks_level_3 {
                append(&g.blocks, b)
            }
    }
}


// -- reset ball --
reset_ball :: proc(g: ^Game) {

    g.ball_pos.y = f32(SCREEN_HEIGHT) / 2.0
    g.ball_pos.x = f32(SCREEN_WIDTH) / 2.0
    g.ball_speed_x = 0.0      // Starta utan sidledshastighet
    g.ball_speed_y = 300.0
}
