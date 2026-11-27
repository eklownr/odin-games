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


// -- Portal: mörk bas + långa tunna streck som glider in mot spelplanen --
draw_portal :: proc(portal: Portal) {
    t := f32(rl.GetTime()) / PORTAL_PULSE_PERIOD
    step := int(t)
    phase := t - f32(step)
    pulse := anim_smoothstep(phase) // 0 -> 1 under varje puls

    // Subtil glow: stora lager först, starkast närmast portalen
    for layer in 0..<PORTAL_GLOW_LAYERS {
        idx := PORTAL_GLOW_LAYERS - 1 - layer
        pad := PORTAL_GLOW_STEP * f32(idx + 1) * portal.scale
        glow := PORTAL_GLOW_COLOR
        a := f32(PORTAL_GLOW_ALPHA) * (1.0 - f32(idx) / f32(PORTAL_GLOW_LAYERS))
        a *= 0.85 + 0.15 * pulse // liten andning i takt med pulsen
        glow.a = u8(a)
        glow_rect := rl.Rectangle{
            portal.rect.x - pad,
            portal.rect.y - pad,
            portal.rect.width + 2.0 * pad,
            portal.rect.height + 2.0 * pad,
        }
        rl.DrawRectangleRounded(glow_rect, 0.3, 0, glow)
    }

    rl.DrawRectangleRounded(portal.rect, 0.2, 0, PORTAL_BASE_COLOR)

    streak_width  := PORTAL_STREAK_WIDTH * portal.scale
    streak_height := PORTAL_STREAK_HEIGHT * portal.scale
    edge_margin: f32 = streak_width / 2.0 + 2.0

    for i in 0..<PORTAL_STREAK_COUNT {
        // 0 = ytterst mot väggen, 1 = innerst mot spelplanen
        slot := (f32(i) + 0.5) / f32(PORTAL_STREAK_COUNT) + pulse * PORTAL_STREAK_INWARD
        color := PORTAL_PULSE_COLORS[(step + i) % PORTAL_STREAK_COUNT]

        if portal.dir == .UP {
            // Tak: långa horisontella streck som rör sig nedåt
            y := portal.rect.y + edge_margin + slot * (portal.rect.height - 2.0 * edge_margin)
            long_offset := (portal.rect.width - streak_height) / 2.0
            streak := rl.Rectangle{
                portal.rect.x + long_offset,
                y - streak_width / 2.0,
                streak_height,
                streak_width,
            }
            rl.DrawRectangleRec(streak, color)
        } else {
            // Vägg: långa vertikala streck som rör sig in från väggen
            span := portal.rect.width - 2.0 * edge_margin
            x := f32(0)
            if portal.dir == .LEFT {
                x = portal.rect.x + edge_margin + slot * span
            } else {
                x = portal.rect.x + portal.rect.width - edge_margin - slot * span
            }
            long_offset := (portal.rect.height - streak_height) / 2.0
            streak := rl.Rectangle{
                x - streak_width / 2.0,
                portal.rect.y + long_offset,
                streak_width,
                streak_height,
            }
            rl.DrawRectangleRec(streak, color)
        }
    }
}


// -- Nyckeln i level 7: gul nyckel med hål, skaft och tänder --
draw_key :: proc(g: ^Game) {
    if g.current_level != 7 || g.has_key { return }

    x := KEY_RECT.x
    y := KEY_RECT.y
    rl.DrawRectangleRec(rl.Rectangle{x + 32.0, y + 12.0, 5.0, 9.0}, KEY_COLOR)
    rl.DrawRectangleRec(rl.Rectangle{x + 40.0, y + 12.0, 5.0, 9.0}, KEY_COLOR)
    rl.DrawRectangleRec(rl.Rectangle{x + 14.0, y + 6.0, 34.0, 8.0}, KEY_COLOR)
    rl.DrawCircleV(rl.Vector2{x + 10.0, y + 10.0}, 10.0, KEY_COLOR)
    rl.DrawCircleV(rl.Vector2{x + 10.0, y + 10.0}, 4.0, level_bg(g.current_level))
}

// -- Lådan i level 9: brun låda med stort nyckelhål --
draw_box :: proc(g: ^Game) {
    if g.current_level != 9 { return }

    r := BOX_RECT
    rl.DrawRectangleRounded(r, 0.12, 0, BOX_BORDER)
    inner := rl.Rectangle{r.x + 4.0, r.y + 4.0, r.width - 8.0, r.height - 8.0}
    rl.DrawRectangleRounded(inner, 0.12, 0, BOX_COLOR)

    hole_color := rl.BLACK
    if g.box_unlocked { hole_color = KEY_COLOR }
    cx := r.x + r.width / 2.0
    cy := r.y + r.height / 2.0 - 8.0
    rl.DrawCircleV(rl.Vector2{cx, cy}, 14.0, hole_color)
    rl.DrawRectangleRec(rl.Rectangle{cx - 6.0, cy, 12.0, 30.0}, hole_color)
}


// -- Stor 7-segment-siffra på bakgrunden (ca 50% transparant svart) --
draw_level_digit :: proc(digit: int) {
    if digit < 0 || digit > 9 { return }

    x: f32 = (f32(SCREEN_WIDTH) - 200.0) / 2.0
    y: f32 = (f32(SCREEN_HEIGHT) - 340.0) / 2.0
    w: f32 = 200.0
    h: f32 = 340.0
    t: f32 = 26.0
    vlen: f32 = (h - 3.0 * t) / 2.0

    // a=överst, b=övre höger, c=nedre höger, d=nederst,
    // e=nedre vänster, f=övre vänster, g=mitten
    segs := [7]rl.Rectangle{
        {x + t,     y,               w - 2.0*t, t},
        {x + w - t, y + t,           t, vlen},
        {x + w - t, y + (h + t)/2.0, t, vlen},
        {x + t,     y + h - t,       w - 2.0*t, t},
        {x,         y + (h + t)/2.0, t, vlen},
        {x,         y + t,           t, vlen},
        {x + t,     y + (h - t)/2.0, w - 2.0*t, t},
    }

    mask := LEVEL_SEGMENTS[digit]
    for i in 0..<7 {
        if ((mask >> u8(i)) & 1) != 0 {
            rl.DrawRectangleRec(segs[i], LEVEL_DIGIT_COLOR)
        }
    }
}


///////////////////////////////////////////
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

    // Stor siffra på bakgrunden: nuvarande level, mål-level när röret börjar
    digit := g.current_level
    if g.state == .TUBE || g.state == .ZOOM_OUT { digit = g.pending_level }
    draw_level_digit(digit)

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

    // -- Portaler: mörk bas med pulserande färgstreck --
    for portal in g.portals {
        draw_portal(portal)
    }

    // -- Nyckel (level 7) och låda (level 9) --
    draw_key(g)
    draw_box(g)

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
    score_text := fmt.ctprintf("Score: %d", g.score)
    hud_color := rl.DARKGRAY
    if g.state != .PLAY { hud_color = rl.WHITE }
    rl.DrawText(score_text, 10, 10, 24, hud_color)

    // Segertext / påminnelse om nyckeln (utanför kameran)
    if g.won {
        msg1: cstring = "Grattis!"
        msg2: cstring = "Du klarade spelet."
        w1 := rl.MeasureText(msg1, 40)
        w2 := rl.MeasureText(msg2, 30)
        rl.DrawText(msg1, i32(SCREEN_WIDTH)/2 - w1/2, 240, 40, rl.DARKGRAY)
        rl.DrawText(msg2, i32(SCREEN_WIDTH)/2 - w2/2, 300, 30, rl.DARKGRAY)
    } else if g.missing_key_timer > 0 {
        msg: cstring = "Nyckel saknas"
        w := rl.MeasureText(msg, 24)
        rl.DrawText(msg, i32(SCREEN_WIDTH)/2 - w/2, 240, 24, rl.DARKGRAY)
    }
    rl.EndDrawing()
}
