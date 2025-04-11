shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
// render_mode unshaded; // Możesz zostawić lub usunąć

void fragment() {
    // Teraz odwołanie do SCREEN_TEXTURE w tej linii jest poprawne,
    // bo zadeklarowaliśmy uniform o tej nazwie powyżej.
    vec4 original_color = texture(SCREEN_TEXTURE, SCREEN_UV);

    // Oblicz wartość skali szarości (standardowa formuła luminancji)
    float grayscale = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));
    // Ustaw kolor wyjściowy na odcień szarości, zachowując oryginalną alfę
    COLOR = vec4(vec3(grayscale), original_color.a);
}