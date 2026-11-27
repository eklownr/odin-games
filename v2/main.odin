package main

import rl "vendor:raylib"
import "core:math"
import "core:fmt"


// --- Konstanter ---
SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 600
BALL_RADIUS   :: 10.0
PADDLE_WIDTH  :: 100.0
PADDLE_HEIGHT :: 20.0


// --- Datatyper ---
Block :: struct {
    pos: rl.Vector2,
    size: rl.Vector2,
    active: bool, // Avgör om blocket ska ritas/kollidera
    color: rl.Color,
}

Game :: struct {
    bg_image:       rl.Texture2D,
    score_text:     cstring,
    score:          int,
    ball_pos:       rl.Vector2,
    ball_speed_x:   f32,
    ball_speed_y:   f32,
    target_speed:   f32,
    paddle_x:       f32,
    paddle_y:       f32,
    paddle_speed:   f32,
    blip_low:       rl.Sound,
    blip_mid:       rl.Sound,
    blip_high:      rl.Sound,
    blip_high2:     rl.Sound,
    blocks:         [dynamic]Block, // Lista med block
    blocks_level_1: [dynamic]Block, // Lista med block
    blocks_level_2: [dynamic]Block, // Lista med block
}

/////////////////////////////////////////////
// --- Uppdateringslogik (Input & Fysik) ---
update_game :: proc(g: ^Game, dt: f32) {
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

    // -- Reset vid golvet --
    if g.ball_pos.y - BALL_RADIUS > f32(SCREEN_HEIGHT) {
        rl.PlaySound(g.blip_high2)
        // Restart level 1
        set_new_level(g, 1)
        reset_ball(g)
        g.score = 0
        g.target_speed = 300
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

    // -- Ny level --
    // Om det inte finns några block, starta level2
    if len(g.blocks) == 0 {
        set_new_level(g, 2)
        reset_ball(g)
    }
}


/////////////////////////////////////////////
// -- Ritlogik (Grafik) --
draw_game :: proc(g: ^Game) {
    rl.BeginDrawing()
    rl.ClearBackground(rl.SKYBLUE)

      // Add background picture
//    rl.DrawTextureEx(
//        g.bg_image, 
//        {0, 0}, 
//        0.0, // Rotation
//        f32(rl.GetScreenWidth()) / f32(g.bg_image.width), // Skala X för att fylla bredden
//        rl.WHITE
//    )
    
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


/////////////////////////////////////////////
// 3. Main (Initiering & Loop)
main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Odin Breakout")
    defer rl.CloseWindow()

//    bg_texture := rl.LoadTexture("val.gif")
//    // Kontrollera att bilden laddades korrekt
//    if bg_texture.id == 0 {
//        fmt.println("Fel: Kunde inte ladda bakgrundsbilden!")
//        return
//    }
//    defer rl.UnloadTexture(bg_texture)

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
        //bg_image    = bg_texture
    }

    defer rl.UnloadSound(game.blip_low)
    defer rl.UnloadSound(game.blip_mid)
    defer rl.UnloadSound(game.blip_high)
    defer rl.UnloadSound(game.blip_high2)

    // Sätt pitchen EN gång vid start:
    rl.SetSoundPitch(game.blip_low, 0.8)
    rl.SetSoundPitch(game.blip_mid, 1.0)
    rl.SetSoundPitch(game.blip_high, 1.5)
    rl.SetSoundPitch(game.blip_high2, 2.0)

    // Lägg till 7 block per rad, med olika färger
    for i in 0..<28 {
        block := Block{
            pos    = {50.0 + f32(i) * 102.0, 50.0},
            size   = {90.0, 30.0},
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

        append(&game.blocks_level_1, block)
        append(&game.blocks_level_2, block)

        // remove blocks to make a triangel
        if i==7 || i==13 || i==14 || i==15 || i==19 || i==20 || i==21 || i==22 || i==23 || i==25 || i==26 || i==27 {
            continue
        } else {
            append(&game.blocks, block)
        }
    }


    // Sett flagga: avsluta game loop
    should_close: bool = false

    for !rl.WindowShouldClose() && !should_close {
        dt := rl.GetFrameTime()
        
        update_game(&game, dt) // Uppdatera logik
        draw_game(&game)       // Rita grafik
        
        if rl.IsKeyDown(.Q) { should_close = true } // Stäng ner med q
    }
}   

//////////////////////////////////////////
// -- Set new Level --
set_new_level :: proc(g: ^Game, lv: int) {
    // reset game blocks, Töm den nuvarande listan först
    resize(&g.blocks, 0)
    g.target_speed = 300 // reset ball speed

    // Kopiera alla element från level_1 till blocks
    if lv == 1 {
        for b in g.blocks_level_1 {
            append(&g.blocks, b)
        }
    }
    if lv == 2 {
        for &b in g.blocks_level_2 {
            // Generera slumpmässiga R, G, B värden (0-255)
            r_val := u8(rl.GetRandomValue(0, 255))
            g_val := u8(rl.GetRandomValue(0, 255))
            b_val := u8(rl.GetRandomValue(0, 255))
        
            // Sätt färgen manuellt (Alpha sätts till 255 för heltäckande)
            b.color = rl.Color{r_val, g_val, b_val, 255}
        
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

// -- play random blip sound --
random_blip :: proc(g: ^Game) {
    // Metod: Slumpa ett heltal mellan 0 och 2200, dividera med 1000.0, lägg till 0.8
    rand_int := rl.GetRandomValue(0, 2200) // 0 till 2200
    rand_sound := 0.8 + f32(rand_int) / 1000.0 // 0.8 - 3.0
    rl.SetSoundPitch(g.blip_low, rand_sound)
    rl.PlaySound(g.blip_low)
}