package main

import rl "vendor:raylib"


// --- Konstanter ---
SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 600
BALL_RADIUS   :: 10.0
PADDLE_WIDTH  :: 100.0
PADDLE_HEIGHT :: 20.0

BLIP_POOL_COUNT :: 5           // Antal samtidiga block-ljud
BLIP_COOLDOWN   :: 0.05        // Minsta tid (s) mellan block-ljud


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
    blip_pool:      [BLIP_POOL_COUNT]rl.Sound, // Aliaser för block-ljud
    last_blip_time: f64,                       // För att undvika ljud-stapling
    blocks:         [dynamic]Block, // Lista med block (aktiv level)
    blocks_level_1: [dynamic]Block, // Lista med block (level 1 template)
    blocks_level_2: [dynamic]Block, // Lista med block (level 2 template)
    blocks_level_3: [dynamic]Block, // Lista med block (level 3 template)
    current_level:  int,            // Vilken level spelas just nu
}
