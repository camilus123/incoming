// Additive, unlit glow used by pooled tracers, flashes and explosions.
// Colour and brightness are per instance, so every pooled mesh shares one material.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float intensity = 1.0;

void fragment() {
	ALBEDO = tint.rgb * intensity;
	ALPHA = tint.a;
}
