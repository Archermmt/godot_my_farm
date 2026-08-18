shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 2.0;
uniform float softness = 0.004;
uniform vec4 curtain_color : source_color = vec4(0.015, 0.02, 0.02, 1.0);

void fragment() {
	vec2 offset = UV - center;
	offset.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float distance_from_center = length(offset);
	float curtain = smoothstep(radius - softness, radius + softness, distance_from_center);
	COLOR = vec4(curtain_color.rgb, curtain_color.a * curtain);
}
