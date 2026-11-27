package main

import rl "vendor:raylib"
import "core:math"


/////////////////////////////////////////////
// --- Uppdateringslogik (Input & Fysik) ---
update_game :: proc(g: ^Game, dt: f32) {
    // Level-animationen kör självständigt: frys vanligt spel under tiden
    update_transition(g, dt)
    if g.state != .PLAY { return }

    // Portaler växer direkt när alla block är borta (även hittboxen)
    update_portal_scale(g)

    // Paddel-rörelse
    if rl.IsKeyDown(.LEFT)  { g.paddle_x -= g.paddle_speed * dt }
    if rl.IsKeyDown(.RIGHT) { g.paddle_x += g.paddle_speed * dt }
    
    // Begränsa paddeln till skärmen
    if g.paddle_x < 0 { g.paddle_x = 0 }
    if g.paddle_x > f32(SCREEN_WIDTH) - PADDLE_WIDTH {
        g.paddle_x = f32(SCREEN_WIDTH) - PADDLE_WIDTH
    }

    // Uppdatera bollens position med X och Y hastighet
    g.ball_pos.x += g.ball_speed_x * dt
    g.ball_pos.y += g.ball_speed_y * dt

    // -- Portaler: enda sättet att byta level --
    // Kontrolleras före vägg-/takkollision så bollen hinner nå portalen
    for portal in g.portals {
        if rl.CheckCollisionCircleRec(g.ball_pos, BALL_RADIUS, portal.rect) {
            rl.PlaySound(g.blip_high)
            start_transition(g, portal.target_level, portal.dir)
            return
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

    // -- Reset vid golvet: börja om samma level --
    if g.ball_pos.y - BALL_RADIUS > f32(SCREEN_HEIGHT) {
        rl.PlaySound(g.blip_high2)
        set_new_level(g, g.current_level)
        reset_ball(g)
    }
    

    //////////////////////////
    // -- Gå igenom alla block --
    for &block in g.blocks {
        if !block.active { continue } // Hoppa över förstörda block
    
        // Skapa en rektangel för blocket
        block_rect := rl.Rectangle{
            x = block.pos.x,
            y = block.pos.y,
            width = block.size.x,
            height = block.size.y,
        }
        
        // kollision boll och block
        if rl.CheckCollisionCircleRec(g.ball_pos, BALL_RADIUS, block_rect) {
            block.active = false // Markera som förstörd
            g.score += 1 // öka scor med ett vid kollision
            random_blip(g) // random blip-ljud
            g.target_speed += 10 // öka total hastighet på bollen varje träff av block
            // Enkel studs (vänd Y-hastighet)
            g.ball_speed_y *= -1.0
            
            // FIXA Kommer bollen upp ifrån eller under ifrån?
            // Flytta ut bollen ur blocket för att undvika dubbelkollision
            g.ball_pos.y = block.pos.y + block.size.y + BALL_RADIUS 
        }
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

    // Att sista blocket försvinner byter inte level – portalerna växer bara
    update_portal_scale(g)
}
