package main

import rl "vendor:raylib"


// -- Skapa en pool av ljud-alias (delar PCM, men egen buffer) --
init_blip_pool :: proc(g: ^Game) {
    pitches := [BLIP_POOL_COUNT]f32{0.9, 1.2, 1.5, 1.9, 2.4}
    for i in 0..<BLIP_POOL_COUNT {
        g.blip_pool[i] = rl.LoadSoundAlias(g.blip_low)
        rl.SetSoundPitch(g.blip_pool[i], pitches[i])
    }
    g.last_blip_time = -BLIP_COOLDOWN
}


// -- Städa upp aliaserna (innan original-ljudet unloadas) --
unload_blip_pool :: proc(g: ^Game) {
    for i in 0..<BLIP_POOL_COUNT {
        rl.UnloadSoundAlias(g.blip_pool[i])
    }
}


// -- play random blip sound --
random_blip :: proc(g: ^Game) {
    // Hoppa över om ett block träffades alldeles nyss (undvik klick/brus)
    now := rl.GetTime()
    if now - g.last_blip_time < BLIP_COOLDOWN { return }
    g.last_blip_time = now

    // Välj en ledig alias slumpmässigt så överlappande ljud inte kapas
    start := int(rl.GetRandomValue(0, BLIP_POOL_COUNT - 1))
    index := start
    for i in 0..<BLIP_POOL_COUNT {
        candidate := (start + i) % BLIP_POOL_COUNT
        if !rl.IsSoundPlaying(g.blip_pool[candidate]) {
            index = candidate
            break
        }
    }

    rl.PlaySound(g.blip_pool[index])
}
