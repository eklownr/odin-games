package main

import rl "vendor:raylib"
import "core:fmt"


level_bg :: proc(level: int) -> rl.Color {
    i := level - 1
    if i < 0 || i >= LEVEL_COUNT { i = 0 }
    return BG_COLORS[i]
}

// Hur synligt röret är under animationen (0 = helt borta)
tube_alpha :: proc(g: ^Game) -> f32 {
    switch g.state {
        case .ZOOM_IN:
            return anim_smoothstep(g.transition_timer / ANIM_ZOOM_IN_TIME) * 255.0
        case .TUBE:
            return 255.0
        case .ZOOM_OUT:
            return (1.0 - anim_smoothstep(g.transition_timer / ANIM_ZOOM_OUT_TIME)) * 255.0
        case .PLAY:
            return 0.0
    }
    return 0.0
}


/////////////////////////////////////////////
// -- Ritlogik (Grafik) --
draw_game :: proc(g: ^Game) {
    rl.BeginDrawing()

    // Bakgrund: pastell i spel -> mörk i röret -> pastell igen
    bg := level_bg(g.current_level)
    switch g.state {
        case .ZOOM_IN:
            t := anim_smoothstep(g.transition_timer / ANIM_ZOOM_IN_TIME)
            bg = rl.ColorLerp(bg, ANIM_BG_DARK, t)
        case .TUBE:
            bg = ANIM_BG_DARK
        case .ZOOM_OUT:
            t := anim_smoothstep(g.transition_timer / ANIM_ZOOM_OUT_TIME)
            bg = rl.ColorLerp(ANIM_BG_DARK, level_bg(g.pending_level), t)
        case .PLAY:
            // Oförändrat
    }
    rl.ClearBackground(bg)

    // Allt i världen ritas genom kameran (zoom bara under animationen)
    rl.BeginMode2D(g.camera)

    // -- Röret med studsande boll --
    alpha := tube_alpha(g)
    if alpha > 0.0 {
        cx := g.tube_center.x
        cy := g.tube_center.y
        wall_len: f32 = 500.0
        wall_w: f32 = 16.0

        wall_color := rl.ColorLerp(rl.DARKGRAY, rl.WHITE, g.tube_flash)
        wall_color.a = u8(alpha)
        glow_color := rl.Color{255, 255, 210, u8(alpha * 0.35)}

        if g.tube_dir == .UP {
            // Vertikalt rör: väggar till vänster och höger
            rl.DrawRectangleRounded(rl.Rectangle{cx - ANIM_TUBE_HALF_WIDTH - wall_w, cy - wall_len/2, wall_w, wall_len}, 0.3, 0, wall_color)
            rl.DrawRectangleRounded(rl.Rectangle{cx + ANIM_TUBE_HALF_WIDTH, cy - wall_len/2, wall_w, wall_len}, 0.3, 0, wall_color)
            rl.DrawRectangleRec(rl.Rectangle{cx - ANIM_TUBE_HALF_WIDTH - 6, cy - wall_len/2, 6, wall_len}, glow_color)
            rl.DrawRectangleRec(rl.Rectangle{cx + ANIM_TUBE_HALF_WIDTH, cy - wall_len/2, 6, wall_len}, glow_color)
        } else {
            // Horisontellt rör: tak och golv
            rl.DrawRectangleRounded(rl.Rectangle{cx - wall_len/2, cy - ANIM_TUBE_HALF_WIDTH - wall_w, wall_len, wall_w}, 0.3, 0, wall_color)
            rl.DrawRectangleRounded(rl.Rectangle{cx - wall_len/2, cy + ANIM_TUBE_HALF_WIDTH, wall_len, wall_w}, 0.3, 0, wall_color)
            rl.DrawRectangleRec(rl.Rectangle{cx - wall_len/2, cy - ANIM_TUBE_HALF_WIDTH - 6, wall_len, 6}, glow_color)
            rl.DrawRectangleRec(rl.Rectangle{cx - wall_len/2, cy + ANIM_TUBE_HALF_WIDTH, wall_len, 6}, glow_color)
        }
    }

    // -- Portaler: enkla vita smala block i tak/vägg --
    for portal in g.portals {
        rl.DrawRectangleRounded(portal.rect, 0.2, 0, rl.WHITE)
    }

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

    rl.EndMode2D()

    // HUD ritas utanför kameran så den inte zoomas
    score_text := fmt.ctprintf("Score: %d   Level: %d", g.score, g.current_level)
    hud_color := rl.DARKGRAY
    if g.state != .PLAY { hud_color = rl.WHITE }
    rl.DrawText(score_text, 10, 10, 24, hud_color)

    // Sista leveln: enkelt "Klart!"
    if g.current_level == LEVEL_COUNT && g.state == .PLAY {
        msg: cstring = "Klart!"
        tw := rl.MeasureText(msg, 40)
        rl.DrawText(msg, i32(SCREEN_WIDTH)/2 - tw/2, i32(SCREEN_HEIGHT)/2 - 20, 40, rl.DARKGRAY)
    }
    rl.EndDrawing()
}
