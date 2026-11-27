package main

import rl "vendor:raylib"
import "core:math"


/////////////////////////////////////////////
// --- Uppdateringslogik (Input & Fysik) ---

// Kvadrerat avstånd från punkten till rektangeln. Används för att välja
// närmaste block om flera råkar överlappa bollen i samma fysiksteg.
ball_rect_dist_sq :: proc(p: rl.Vector2, r: rl.Rectangle) -> f32 {
    dx: f32 = 0.0
    if p.x < r.x {
        dx = r.x - p.x
    } else if p.x > r.x + r.width {
        dx = p.x - (r.x + r.width)
    }

    dy: f32 = 0.0
    if p.y < r.y {
        dy = r.y - p.y
    } else if p.y > r.y + r.height {
        dy = p.y - (r.y + r.height)
    }
    return dx*dx + dy*dy
}

// Ett fysiksteg för bollen. Returnerar false när spelet avbryts av en
// portal, vinst eller bolltapp, så att update_game kan sluta steppinga.
step_ball :: proc(g: ^Game, dt: f32) -> bool {
    prev_pos := g.ball_pos

    // Uppdatera bollens position med X och Y hastighet
    g.ball_pos.x += g.ball_speed_x * dt
    g.ball_pos.y += g.ball_speed_y * dt

    // -- Portaler: enda sättet att byta rum --
    // Kontrolleras före vägg-/takkollision så bollen hinner nå portalen
    for portal in g.portals {
        if rl.CheckCollisionCircleRec(g.ball_pos, BALL_RADIUS, portal.rect) {
            rl.PlaySound(g.blip_high)
            start_transition(g, portal.target_room, portal.dir)
            return false
        }
    }

    // -- Nyckeln i rum 7: plockas när bollen träffar den --
    if g.current_room == 7 && !g.has_key {
        if rl.CheckCollisionCircleRec(g.ball_pos, BALL_RADIUS, KEY_RECT) {
            g.has_key = true
            g.score += 5
            rl.PlaySound(g.blip_high2)
        }
    }

    // -- Kistan i rum 9 --
    if g.current_room == 9 && !g.box_unlocked {
        if rl.CheckCollisionCircleRec(g.ball_pos, BALL_RADIUS, BOX_RECT) {
            if g.has_key {
                // Upplåst: visa Grattis-texten och frys spelet
                g.box_unlocked = true
                g.won = true
                g.ball_speed_x = 0
                g.ball_speed_y = 0
                rl.PlaySound(g.blip_high2)
                return false
            }

            // Ingen nyckel: kort meddelande och studsa ut bollen ur kistan
            g.missing_key_timer = MISSING_KEY_TIME
            rl.PlaySound(g.blip_low)
            if g.ball_speed_y > 0 {
                g.ball_pos.y = BOX_RECT.y - BALL_RADIUS
            } else {
                g.ball_pos.y = BOX_RECT.y + BOX_RECT.height + BALL_RADIUS
            }
            g.ball_speed_y *= -1.0
        }
    }

    /////////////////////////////////////////
    // -- Kollision med Paddel --
    paddle_rect := rl.Rectangle{x = g.paddle_x, y = g.paddle_y, width = PADDLE_WIDTH, height = PADDLE_HEIGHT}

    if rl.CheckCollisionCircleRec(g.ball_pos, BALL_RADIUS, paddle_rect) {
        // spela ljud vid kollision
        rl.PlaySound(g.blip_high)

        // 1. Beräkna ny riktning baserat på träffpunkt
        hit_offset := g.ball_pos.x - (g.paddle_x + PADDLE_WIDTH/2.0)
        normalized_offset := hit_offset / (PADDLE_WIDTH/2.0)

        g.ball_speed_y = -300.0 // Studsa uppåt med basfart
        g.ball_speed_x = normalized_offset * 400.0 // Lägg till sidledshastighet

        // 2. NORMALISERA (Detta fixar hastigheten automatiskt)
        current_speed := math.sqrt(g.ball_speed_x*g.ball_speed_x + g.ball_speed_y*g.ball_speed_y)

        if current_speed != 0.0 {
            //g.target_speed = f32(300) // Konstant totalfart
            g.ball_speed_x = (g.ball_speed_x / current_speed) * g.target_speed
            g.ball_speed_y = (g.ball_speed_y / current_speed) * g.target_speed
        }

        // Se till att bollen bara studsar om den kommer uppifrån (för att undvika att den fastnar)
        if g.ball_speed_y > 0 && g.ball_pos.y < g.paddle_y + PADDLE_HEIGHT {

            // 1. Beräkna var på paddeln bollen träffade (Relativt till mitten)
            // Paddelns mitt-x
            paddle_center_x := g.paddle_x + PADDLE_WIDTH / 2.0

            // Avståndet från mitten (-50 till +50 om paddeln är 100 bred)
            hit_offset := g.ball_pos.x - paddle_center_x

            // Normalisera värdet till mellan -1.0 (vänster kant) och 1.0 (höger kant)
            normalized_offset := hit_offset / (PADDLE_WIDTH / 2.0)

            // 2. Sätt nya hastigheter
            g.ball_speed_y *= -1.0 // Alltid studsa uppåt

            // Ändra X-hastigheten baserat på var den träffade
            // T.ex. max 400 hastighet i sidled
            g.ball_speed_x = normalized_offset * 400.0

            // Flytta ut bollen ur paddeln så den inte fastnar
            g.ball_pos.y = g.paddle_y - BALL_RADIUS
        }
    }

    //  -- Väggkollision (Vänster/Höger) --
    if g.ball_pos.x - BALL_RADIUS <= 0 {
            rl.PlaySound(g.blip_mid)
        g.ball_pos.x = BALL_RADIUS
        g.ball_speed_x *= -1.0
    } else if g.ball_pos.x + BALL_RADIUS >= f32(SCREEN_WIDTH) {
            rl.PlaySound(g.blip_mid)
        g.ball_pos.x = f32(SCREEN_WIDTH) - BALL_RADIUS
        g.ball_speed_x *= -1.0
    }

   // -- Studsa på taket --
    if g.ball_pos.y - BALL_RADIUS < f32(0.0) {
        rl.PlaySound(g.blip_high)
        g.ball_pos.y = f32(10) + BALL_RADIUS
        g.ball_speed_y = 300.0
    }

    // -- Reset vid golvet: börja om samma rum --
    if g.ball_pos.y - BALL_RADIUS > f32(SCREEN_HEIGHT) {
        rl.PlaySound(g.blip_high2)
        g.has_key = false // Nyckeln måste hämtas igen i rum 7
        reset_room(g, g.current_room) // Bolltapp nollställer blocken som tidigare
        reset_ball(g)
        return false
    }

    //////////////////////////
    // -- Kollision med block --
    // Bara ett block per steg: annars kan studsen vändas flera gånger.
    hit_index := -1
    hit_rect := rl.Rectangle{}
    hit_dist := f32(0)
    for i := 0; i < len(g.blocks); i += 1 {
        block := g.blocks[i]
        if !block.active { continue } // Hoppa över förstörda block

        block_rect := rl.Rectangle{
            x = block.pos.x,
            y = block.pos.y,
            width = block.size.x,
            height = block.size.y,
        }

        if !rl.CheckCollisionCircleRec(g.ball_pos, BALL_RADIUS, block_rect) { continue }

        dist := ball_rect_dist_sq(prev_pos, block_rect)
        if hit_index < 0 || dist < hit_dist {
            hit_index = i
            hit_rect = block_rect
            hit_dist = dist
        }
    }

    if hit_index >= 0 {
        g.blocks[hit_index].active = false // Markera som förstörd
        g.score += 1 // öka scor med ett vid kollision
        random_blip(g) // random blip-ljud
        g.target_speed += 10 // öka total hastighet på bollen varje träff av block

        // Minsta "överlappet" avgör vilken sida bollen kom ifrån.
        // Flytta ut den på den sidan och vänd bara rätt hastighetskomponent.
        push_left   := (g.ball_pos.x + BALL_RADIUS) - hit_rect.x
        push_right  := (hit_rect.x + hit_rect.width) - (g.ball_pos.x - BALL_RADIUS)
        push_top    := (g.ball_pos.y + BALL_RADIUS) - hit_rect.y
        push_bottom := (hit_rect.y + hit_rect.height) - (g.ball_pos.y - BALL_RADIUS)

        smallest := push_left
        side := 0 // vänster
        if push_right < smallest {
            smallest = push_right
            side = 1 // höger
        }
        if push_top < smallest {
            smallest = push_top
            side = 2 // uppifrån
        }
        if push_bottom < smallest {
            smallest = push_bottom
            side = 3 // underifrån
        }

        switch side {
            case 0: // vänster sida
                g.ball_pos.x = hit_rect.x - BALL_RADIUS
                if g.ball_speed_x > 0 { g.ball_speed_x *= -1.0 }
            case 1: // höger sida
                g.ball_pos.x = hit_rect.x + hit_rect.width + BALL_RADIUS
                if g.ball_speed_x < 0 { g.ball_speed_x *= -1.0 }
            case 2: // uppifrån
                g.ball_pos.y = hit_rect.y - BALL_RADIUS
                if g.ball_speed_y > 0 { g.ball_speed_y *= -1.0 }
            case 3: // underifrån
                g.ball_pos.y = hit_rect.y + hit_rect.height + BALL_RADIUS
                if g.ball_speed_y < 0 { g.ball_speed_y *= -1.0 }
        }
    }

    return true
}

update_game :: proc(g: ^Game, dt: f32) {
    // Rum-animationen kör självständigt: frys vanligt spel under tiden
    update_transition(g, dt)
    if g.state != .PLAY { return }

    // Efter segern fryses allt (Q fungerar fortfarande i main-loopen)
    if g.won { return }

    // Klampa långa frames så bollen inte flyttas för långt i ett svep
    frame_dt := dt
    if frame_dt > MAX_FRAME_DT { frame_dt = MAX_FRAME_DT }

    if g.missing_key_timer > 0 {
        g.missing_key_timer -= frame_dt
        if g.missing_key_timer < 0 { g.missing_key_timer = 0 }
    }

    // Portaler växer direkt när alla block är borta (även hittboxen)
    update_portal_scale(g)

    // Paddel-rörelse
    if rl.IsKeyDown(.LEFT)  { g.paddle_x -= g.paddle_speed * frame_dt }
    if rl.IsKeyDown(.RIGHT) { g.paddle_x += g.paddle_speed * frame_dt }

    // Begränsa paddeln till skärmen
    if g.paddle_x < 0 { g.paddle_x = 0 }
    if g.paddle_x > f32(SCREEN_WIDTH) - PADDLE_WIDTH {
        g.paddle_x = f32(SCREEN_WIDTH) - PADDLE_WIDTH
    }

    // Dela upp bollens rörelse i små steg så den inte kan hoppa igenom
    // block eller paddeln, även när farten ökar för varje träff.
    speed := math.sqrt(g.ball_speed_x*g.ball_speed_x + g.ball_speed_y*g.ball_speed_y)
    steps := 1
    if speed * frame_dt > BALL_MAX_STEP {
        steps = int(math.ceil(speed * frame_dt / BALL_MAX_STEP))
        if steps > BALL_MAX_STEPS { steps = BALL_MAX_STEPS }
    }
    sub_dt := frame_dt / f32(steps)
    for _ in 0..<steps {
        if !step_ball(g, sub_dt) { break }
    }

    // Rensa listan (Ta bort inaktiva block)
    new_blocks: [dynamic]Block
    for block in g.blocks {
        if block.active {
            append(&new_blocks, block)
        }
    }

    // Byt ut den gamla listan mot den nya och städa minnet
    delete(g.blocks)
    g.blocks = new_blocks

    // Att sista blocket försvinner byter inte rum – portalerna växer bara
    update_portal_scale(g)
}
