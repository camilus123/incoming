// The night sky's stars: one mesh of points on a huge sphere around the turret.
shader_type spatial;
render_mode unshaded, blend_add, fog_disabled, depth_draw_never, shadows_disabled;

uniform float brightness = 1.0;
uniform float point_scale = 1.0;

void vertex() {
	// UV.x carries the star's size in pixels at 1080 lines.
	POINT_SIZE = max(1.5, UV.x * point_scale);
}

void fragment() {
	float falloff = smoothstep(0.5, 0.05, length(POINT_COORD - vec2(0.5)));
	ALBEDO = COLOR.rgb * brightness * falloff;
	ALPHA = 1.0;
}
