package main

import rl "vendor:raylib"
import "core:fmt"


/////////////////////////////////////////////
// -- Ritlogik (Grafik) --
draw_game :: proc(g: ^Game) {
    rl.BeginDrawing()

    // Ljus pastellbakgrund beroende på level
    level_index := g.current_level - 1
    if level_index < 0 || level_index >= LEVEL_COUNT { level_index = 0 }
    rl.ClearBackground(BG_COLORS[level_index])
    
    // -- Rita Paddel --
    rect_pad := rl.Rectangle{g.paddle_x, g.paddle_y, PADDLE_WIDTH, PADDLE_HEIGHT}
    rl.DrawRectangleRounded(rect_pad, 0.6, 0, rl.BLACK)
    rect_pad2 := rl.Rectangle{g.paddle_x+5, g.paddle_y+5, PADDLE_WIDTH-10, PADDLE_HEIGHT-10}
    rl.DrawRectangleRounded(rect_pad2, 0.6, 0, rl.GREEN)
    
    // Rita Boll
    rl.DrawCircleV(g.ball_pos, BALL_RADIUS+5, rl.BLACK)
    rl.DrawCircleV(g.ball_pos, BALL_RADIUS, rl.WHITE)

    // Rita alla aktiva block
    for block in g.blocks {
        if block.active {
            // stor svart rektangel (skapar svart kant)
            rect := rl.Rectangle{block.pos.x-5, block.pos.y-5, block.size.x+10, block.size.y+10}
            rl.DrawRectangleRounded(rect, 0.2, 0, rl.BLACK)
            // mitten med färg
            rect2 := rl.Rectangle{block.pos.x, block.pos.y, block.size.x, block.size.y}
            rl.DrawRectangleRounded(rect2, 0.2, 0, block.color)
 
        }
    }
    
    score_text := fmt.ctprintf("Score: %d", g.score)
    rl.DrawText(score_text, 10, 10, 24, rl.DARKGRAY)
    rl.EndDrawing()
}
