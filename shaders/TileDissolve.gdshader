shader_type canvas_item;

// Różne render_mode, jeśli chcesz np. unshaded, additive, itd.
render_mode blend_mix, unshaded;

// Parametry do sterowania efektem
uniform float progress: hint_range(0,1) = 0.0;
uniform float speed: hint_range(0,10) = 2.0;
uniform vec4 main_color = vec4(1.0, 1.0, 1.0, 1.0);

// Mogą być inne uniformy: np. tekstura noise, texture baseColor, itp.
uniform sampler2D noise_tex;

void fragment() {
    // 1. Pobierz współrzędne UV piksela
    vec2 uv = UV;
    
    // 2. Pobierz wartość z noise_tex, np.:
    float noise_val = texture(noise_tex, uv).r;
    
    // 3. Porównaj z progress
    if (noise_val < progress) {
        // „Wypal” / „wytnij” piksel 
        // – na przykład całkowicie przezroczysty kolor:
        COLOR = vec4(0.0);
        // Możesz też zrobić discard; w 2D z discard czasem bywa problem 
        // w połączeniu z blend_mode, ale to zależy od potrzeby.
        // discard;
    } else {
        // Normalny kolor
        COLOR = main_color;
    }
}
