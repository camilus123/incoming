// Full-screen lens effects drawn over the finished 3D picture and under the HUD:
// chromatic aberration, a ripple when the shield is hit, and lens dirt that
// lights up on big explosions. The rectangle is hidden while all three are idle,
// so the effect costs nothing most of the time.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float aberration = 0.0;
uniform float ripple = 0.0;
uniform float ripple_phase = 0.0;
uniform float dirt = 0.0;
uniform vec3 dirt_color : source_color = vec3(1.0, 0.8, 0.6);
uniform float aspect = 1.78;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Soft round smudges scattered over the lens.
float smudges(vec2 uv) {
	float total = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		float cells = layer == 0 ? 5.0 : 11.0;
		vec2 grid = uv * vec2(cells * aspect, cells);
		vec2 cell = floor(grid);
		vec2 centre = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.6 + 0.2;
		float size = 0.12 + 0.3 * hash(cell + 11.3);
		float spot = smoothstep(size, size * 0.3, length(fract(grid) - centre));
		total += spot * step(0.55, hash(cell + 1.9)) * (layer == 0 ? 0.6 : 0.4);
	}
	return total;
}

void fragment() {
	vec2 centred = SCREEN_UV - vec2(0.5);
	vec2 round = centred * vec2(aspect, 1.0);
	float distance_from_centre = length(round);
	vec2 uv = SCREEN_UV;
	// Shield hit: a ring of refraction that runs outward from the centre.
	if (ripple > 0.001) {
		float wave = sin(distance_from_centre * 42.0 - ripple_phase * 16.0);
		float ring = smoothstep(0.28, 0.0, abs(distance_from_centre - ripple_phase * 0.9));
		uv += normalize(centred + vec2(0.0001)) * wave * ring * ripple * 0.012;
	}
	vec2 shift = centred * aberration * 0.007 * (0.3 + distance_from_centre * 1.6);
	vec3 color;
	color.r = texture(screen_texture, uv + shift).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - shift).b;
	color += dirt_color * smudges(SCREEN_UV) * dirt * (0.4 + distance_from_centre);
	COLOR = vec4(color, 1.0);
}
