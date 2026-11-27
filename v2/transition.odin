package main

import rl "vendor:raylib"


// Mjuk in/ut-zoom (smoothstep)
anim_smoothstep :: proc(t: f32) -> f32 {
    x := t
    if x < 0.0 { x = 0.0 }
    if x > 1.0 { x = 1.0 }
    return x * x * (3.0 - 2.0 * x)
}

anim_lerp :: proc(a, b, t: f32) -> f32 {
    return a + (b - a) * t
}

// Hastigheten som bollen färdas genom röret med (lagom för att komma hela vägen)
tube_travel_speed :: proc(dir: Tube_Direction) -> f32 {
    if dir == .UP { return (2.0 * ANIM_TUBE_UP_HALF_LENGTH) / ANIM_TUBE_TIME }
    return (2.0 * ANIM_TUBE_SIDE_HALF_LENGTH) / ANIM_TUBE_TIME
}


// -- Starta animationen istället för att byta rum direkt --
start_transition :: proc(g: ^Game, next_room: int, dir: Tube_Direction) {
    g.pending_room = next_room
    g.transition_timer = 0
    g.tube_center = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0}
    g.transition_from = g.ball_pos
    g.tube_flash = 0
    g.tube_dir = dir // Riktningen kommer från portalen

    clear_portals(g)

    cx := g.tube_center.x
    cy := g.tube_center.y
    switch g.tube_dir {
        case .UP:
            g.tube_start = {cx, cy + ANIM_TUBE_UP_HALF_LENGTH} // nere i röret
        case .RIGHT:
            g.tube_start = {cx - ANIM_TUBE_SIDE_HALF_LENGTH, cy}
        case .LEFT:
            g.tube_start = {cx + ANIM_TUBE_SIDE_HALF_LENGTH, cy}
    }

    g.camera.target = g.ball_pos
    g.camera.zoom = 1.0
    g.state = .ZOOM_IN
}


// -- Kör animationen. Vanligt spel är fryst tills state är PLAY igen --
update_transition :: proc(g: ^Game, dt: f32) {
    if g.tube_flash > 0 {
        g.tube_flash -= dt * 5.0
        if g.tube_flash < 0 { g.tube_flash = 0 }
    }

    if g.state == .PLAY { return }

    g.transition_timer += dt

    switch g.state {
        case .ZOOM_IN:
            // Zooma in mot bollen medan den glider till rörets startläge
            t := anim_smoothstep(g.transition_timer / ANIM_ZOOM_IN_TIME)
            g.ball_pos.x = anim_lerp(g.transition_from.x, g.tube_start.x, t)
            g.ball_pos.y = anim_lerp(g.transition_from.y, g.tube_start.y, t)
            // Kameran lerpar mot rörets mitt (inte bollen) så övergången till
            // röret blir mjuk och bollen hamnar nere/till vänster i bilden
            g.camera.target = {
                anim_lerp(g.transition_from.x, g.tube_center.x, t),
                anim_lerp(g.transition_from.y, g.tube_center.y, t),
            }
            g.camera.zoom = anim_lerp(1.0, ANIM_ZOOM_MAX, t)

            if g.transition_timer >= ANIM_ZOOM_IN_TIME {
                g.state = .TUBE
                g.transition_timer = 0
                g.ball_pos = g.tube_start

                travel := tube_travel_speed(g.tube_dir)
                switch g.tube_dir {
                    case .UP:
                        g.ball_speed_x = ANIM_TUBE_SPEED  // studsar mot sidoväggarna
                        g.ball_speed_y = -travel           // rör sig uppåt
                    case .RIGHT:
                        g.ball_speed_x = travel            // rör sig åt höger
                        g.ball_speed_y = ANIM_TUBE_SPEED  // studsar mot tak/golv
                    case .LEFT:
                        g.ball_speed_x = -travel           // rör sig åt vänster
                        g.ball_speed_y = ANIM_TUBE_SPEED
                }

                g.camera.target = g.tube_center
                g.camera.zoom = ANIM_ZOOM_MAX
            }

        case .TUBE:
            g.ball_pos.x += g.ball_speed_x * dt
            g.ball_pos.y += g.ball_speed_y * dt

            if g.tube_dir == .UP {
                // Studsa mellan vänster och höger vägg
                left  := g.tube_center.x - ANIM_TUBE_HALF_WIDTH + BALL_RADIUS
                right := g.tube_center.x + ANIM_TUBE_HALF_WIDTH - BALL_RADIUS
                if g.ball_pos.x <= left {
                    g.ball_pos.x = left
                    g.ball_speed_x = ANIM_TUBE_SPEED
                    g.tube_flash = 1.0
                    rl.PlaySound(g.blip_mid)
                } else if g.ball_pos.x >= right {
                    g.ball_pos.x = right
                    g.ball_speed_x = -ANIM_TUBE_SPEED
                    g.tube_flash = 1.0
                    rl.PlaySound(g.blip_mid)
                }
            } else {
                // Studsa mellan tak och golv i det horisontella röret
                top    := g.tube_center.y - ANIM_TUBE_HALF_WIDTH + BALL_RADIUS
                bottom := g.tube_center.y + ANIM_TUBE_HALF_WIDTH - BALL_RADIUS
                if g.ball_pos.y <= top {
                    g.ball_pos.y = top
                    g.ball_speed_y = ANIM_TUBE_SPEED
                    g.tube_flash = 1.0
                    rl.PlaySound(g.blip_mid)
                } else if g.ball_pos.y >= bottom {
                    g.ball_pos.y = bottom
                    g.ball_speed_y = -ANIM_TUBE_SPEED
                    g.tube_flash = 1.0
                    rl.PlaySound(g.blip_mid)
                }
            }

            g.camera.target = g.tube_center
            g.camera.zoom = ANIM_ZOOM_MAX

            if g.transition_timer >= ANIM_TUBE_TIME {
                // Byt rum och reset bollen först när röret är klart
                g.tube_exit_pos = g.ball_pos
                g.state = .ZOOM_OUT
                g.transition_timer = 0
                save_current_blocks(g) // Behåll banan om vi senare återvänder hit
                set_new_room(g, g.pending_room)
                reset_ball(g)
                g.camera.target = g.tube_exit_pos
            }

        case .ZOOM_OUT:
            // Zooma ut från bollen medan den glider till startpunkten för nästa rum
            t := anim_smoothstep(g.transition_timer / ANIM_ZOOM_OUT_TIME)
            g.ball_pos.x = anim_lerp(g.tube_exit_pos.x, f32(SCREEN_WIDTH) / 2.0, t)
            g.ball_pos.y = anim_lerp(g.tube_exit_pos.y, f32(SCREEN_HEIGHT) / 2.0, t)
            g.camera.target = g.ball_pos
            g.camera.zoom = anim_lerp(ANIM_ZOOM_MAX, 1.0, t)

            if g.transition_timer >= ANIM_ZOOM_OUT_TIME {
                g.state = .PLAY
                g.camera.target = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0}
                g.camera.zoom = 1.0
            }

        case .PLAY:
            // Inget att göra här
    }
}
