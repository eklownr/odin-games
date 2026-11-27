package main

import rl "vendor:raylib"


// -- play random blip sound --
random_blip :: proc(g: ^Game) {
    // Metod: Slumpa ett heltal mellan 0 och 2200, dividera med 1000.0, lägg till 0.8
    rand_int := rl.GetRandomValue(0, 2200) // 0 till 2200
    rand_sound := 0.8 + f32(rand_int) / 1000.0 // 0.8 - 3.0
    rl.SetSoundPitch(g.blip_low, rand_sound)
    rl.PlaySound(g.blip_low)
}
