package main

import rl "vendor:raylib"


// --- Konstanter ---
SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 600
BALL_RADIUS   :: 10.0
PADDLE_WIDTH  :: 100.0
PADDLE_HEIGHT :: 20.0

LEVEL_COUNT :: 9                 // Antal levels (1-9)

// --- Level-animation: zoom in på bollen, studs i rör, zoom ut ---
ANIM_ZOOM_MAX        :: 6.0      // Hur mycket kameran zoomar in
ANIM_ZOOM_IN_TIME    :: 0.6      // Sekunder
ANIM_TUBE_TIME       :: 2.0
ANIM_ZOOM_OUT_TIME   :: 0.8
ANIM_TUBE_HALF_WIDTH :: 50.0     // Avstånd från rörets mitt till väggarna
ANIM_TUBE_SPEED      :: 350.0    // Studshastighet mot rörväggen
ANIM_TUBE_UP_HALF_LENGTH   :: 40.0 // Bollens väg uppåt (från botten till toppen)
ANIM_TUBE_SIDE_HALF_LENGTH :: 60.0 // Bollens väg åt höger/vänster
ANIM_BG_DARK         :: rl.Color{28, 30, 42, 255}

BLIP_POOL_COUNT :: 5           // Antal samtidiga block-ljud
BLIP_COOLDOWN   :: 0.05        // Minsta tid (s) mellan block-ljud

TEST_SINGLE_BLOCK  :: true     // TILLFÄLLIGT: ett enda block i mitten för test
TEST_ADVANCE_ON_HIT :: false   // TILLFÄLLIGT: byt level vid första blockträff (används ej)

// Ljusa pastellbakgrunder per level
BG_LEVEL_1 :: rl.Color{135, 206, 235, 255} // ljus skyblue
BG_LEVEL_2 :: rl.Color{255, 218, 185, 255} // ljus orange
BG_LEVEL_3 :: rl.Color{216, 191, 216, 255} // ljus lila
BG_LEVEL_4 :: rl.Color{200, 255, 220, 255} // ljus mint
BG_LEVEL_5 :: rl.Color{255, 250, 205, 255} // ljus gul
BG_LEVEL_6 :: rl.Color{255, 225, 235, 255} // ljus rosa
BG_LEVEL_7 :: rl.Color{205, 245, 245, 255} // ljus turkos
BG_LEVEL_8 :: rl.Color{255, 235, 205, 255} // ljus aprikos
BG_LEVEL_9 :: rl.Color{232, 225, 248, 255} // ljus lavendel

BG_COLORS := [LEVEL_COUNT]rl.Color{
    BG_LEVEL_1, BG_LEVEL_2, BG_LEVEL_3,
    BG_LEVEL_4, BG_LEVEL_5, BG_LEVEL_6,
    BG_LEVEL_7, BG_LEVEL_8, BG_LEVEL_9,
}


// --- Datatyper ---
Game_State :: enum {
    PLAY,
    ZOOM_IN,
    TUBE,
    ZOOM_OUT,
}

Tube_Direction :: enum { UP, RIGHT, LEFT }

Block :: struct {
    pos: rl.Vector2,
    size: rl.Vector2,
    active: bool, // Avgör om blocket ska ritas/kollidera
    color: rl.Color,
}

Portal :: struct {
    rect:         rl.Rectangle,
    target_level: int,
    dir:          Tube_Direction,
}

Game :: struct {
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
    blip_pool:      [BLIP_POOL_COUNT]rl.Sound, // Aliaser för block-ljud
    last_blip_time: f64,                       // För att undvika ljud-stapling
    blocks:         [dynamic]Block,              // Lista med block (aktiv level)
    portals:        [dynamic]Portal,             // Portaler i tak/vägg (enda sättet att byta level)
    levels:         [LEVEL_COUNT][dynamic]Block, // Mallar för level 1-9
    current_level:  int,                         // Vilken level spelas just nu

    // Level-animation
    state:            Game_State,
    transition_timer: f32,
    pending_level:    int,
    tube_center:      rl.Vector2,
    transition_from:  rl.Vector2,
    tube_start:       rl.Vector2,
    tube_exit_pos:    rl.Vector2,
    tube_dir:         Tube_Direction,
    tube_flash:       f32,
    camera:           rl.Camera2D,
}
