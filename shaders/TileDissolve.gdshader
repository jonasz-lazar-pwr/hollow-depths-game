shader_type canvas_item;

render_mode blend_mix, unshaded;

uniform float progress: hint_range(0,1) = 0.0;
uniform float speed: hint_range(0,10) = 2.0;
uniform vec4 main_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D noise_tex;

void fragment() {
	vec2 uv = UV;
	float noise_val = texture(noise_tex, uv).r;

	if (noise_val < progress) {
		COLOR = vec4(0.0);
	} else {
		COLOR = main_color;
	}
}
