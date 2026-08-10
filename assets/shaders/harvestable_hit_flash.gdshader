shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;

float dissolve_noise(vec2 uv, vec2 pixel_size) {
	vec2 cell = floor(uv / pixel_size);
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV);
	if (dissolve_amount > 0.0 && dissolve_noise(UV, TEXTURE_PIXEL_SIZE) < dissolve_amount) {
		discard;
	}
	COLOR = vec4(mix(texture_color.rgb, vec3(1.0), flash_amount), texture_color.a);
}
