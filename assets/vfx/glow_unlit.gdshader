// Additive, unlit glow for pooled tracers, flashes, bolts and explosions.
// Every effect of one kind is an instance of one MultiMesh (see GlowBatch):
//   COLOR            tint (rgb) and opacity (a)
//   INSTANCE_CUSTOM  x = start time, y = life in seconds (0 = stays until hidden),
//                    z = size at the start relative to the end, w = brightness
// Fading and growing happen here from the batch clock `now`, so the game sets an
// instance once and never touches it again.
// (Per-instance shader uniforms are deliberately not used: updating them every
// frame locked the frame rate to half the refresh rate of the display.)
shader_type spatial;
// Back faces are culled on purpose: an explosion that engulfs the camera is not drawn,
// so it cannot white out the whole screen.
render_mode unshaded, blend_add, cull_back, shadows_disabled, depth_draw_never;

uniform float now = 0.0;

varying vec4 glow;

void vertex() {
	float remaining = 1.0;
	if (INSTANCE_CUSTOM.y > 0.0) {
		remaining = clamp(1.0 - (now - INSTANCE_CUSTOM.x) / INSTANCE_CUSTOM.y, 0.0, 1.0);
		// Grows from the start size to full size; collapses to nothing when over.
		VERTEX *= mix(1.0, INSTANCE_CUSTOM.z, remaining * remaining) * step(0.0001, remaining);
	}
	glow = vec4(COLOR.rgb * INSTANCE_CUSTOM.w, COLOR.a * remaining);
}

void fragment() {
	ALBEDO = glow.rgb;
	ALPHA = glow.a;
}
