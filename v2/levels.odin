package main

import rl "vendor:raylib"


// -- Portaler: mörka block med pulserande streck i tak/vägg --
clear_portals :: proc(g: ^Game) {
    resize(&g.portals, 0)
}

portal_scale_for :: proc(g: ^Game) -> f32 {
    if len(g.blocks) == 0 { return PORTAL_CLEAR_SCALE }
    return 1.0
}

portal_rect :: proc(dir: Tube_Direction, scale: f32) -> rl.Rectangle {
    cx := f32(SCREEN_WIDTH) / 2.0
    cy := f32(SCREEN_HEIGHT) / 2.0
    thick: f32 = 4.0 * PORTAL_TEST_SCALE * scale
    length: f32 = PORTAL_STREAK_HEIGHT * scale

    r := rl.Rectangle{}
    switch dir {
        case .UP:
            r = {cx - length/2.0, 0, length, thick}
        case .RIGHT:
            r = {f32(SCREEN_WIDTH) - thick, cy - length/2.0, thick, length}
        case .LEFT:
            r = {0, cy - length/2.0, thick, length}
    }
    return r
}

add_portal :: proc(g: ^Game, dir: Tube_Direction, target: int) {
    scale := portal_scale_for(g)
    append(&g.portals, Portal{
        rect         = portal_rect(dir, scale),
        target_level = target,
        dir          = dir,
        scale        = scale,
    })
}

// Uppdatera både hittbox och streckstorlek när blocken tar slut
update_portal_scale :: proc(g: ^Game) {
    scale := portal_scale_for(g)
    for &portal in g.portals {
        portal.scale = scale
        portal.rect = portal_rect(portal.dir, scale)
    }
}

spawn_portals :: proc(g: ^Game) {
    clear_portals(g)

    // Karta:    789
    //           456
    //           123   (start: 2)
    switch g.current_level {
        case 1:
            add_portal(g, .UP, 4)
            add_portal(g, .RIGHT, 2)
        case 2:
            add_portal(g, .LEFT, 1)
            add_portal(g, .RIGHT, 3)
        case 3:
            add_portal(g, .LEFT, 2)
            add_portal(g, .UP, 6)
        case 4:
            add_portal(g, .RIGHT, 5)
        case 5:
            add_portal(g, .LEFT, 4)
            add_portal(g, .RIGHT, 6)
            add_portal(g, .UP, 8)
        case 6:
            add_portal(g, .LEFT, 5)
        case 7:
            add_portal(g, .RIGHT, 8)
        case 8:
            add_portal(g, .LEFT, 7)
            add_portal(g, .RIGHT, 9)
        case 9:
            // Sista leveln: inga portaler, bara "Klart!"
    }
}


////////////////////////////////////////
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
    } else {
        // Level 1 och 3-9 kopieras direkt från sin mall
        for b in g.levels[level-1] {
            append(&g.blocks, b)
        }
    }

    // Portaler finns från start på varje level
    spawn_portals(g)
}


// -- reset ball --
reset_ball :: proc(g: ^Game) {
    g.ball_pos.y = f32(SCREEN_HEIGHT) / 2.0
    g.ball_pos.x = f32(SCREEN_WIDTH) / 2.0
    g.ball_speed_x = 0.0      // Starta utan sidledshastighet
    g.ball_speed_y = 300.0
}
