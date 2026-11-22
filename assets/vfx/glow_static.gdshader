// Additive, unlit glow for the few effects that are ordinary nodes moving with
// their owner (shield bubbles on enemies, weak point markers).
shader_type spatial;
render_mode unshaded, blend_add, cull_back, shadows_disabled, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 1.0;

void fragment() {
	ALBEDO = tint.rgb * intensity;
	ALPHA = tint.a;
}
