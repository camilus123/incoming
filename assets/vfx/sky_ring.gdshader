// The ring of a gas giant: a flat disc with dusty bands, see-through in the gaps.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.8, 0.7, 0.6);
uniform float inner = 0.6;
uniform float brightness = 1.0;
uniform float opacity = 1.0;
// Radius of the planet in the ring's own units (the ring's outer edge is 1).
uniform float planet_radius = 0.45;

varying vec3 local_position;
varying vec3 local_camera;

void vertex() {
	local_position = VERTEX;
	local_camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	// UV runs from the centre (0.5, 0.5); 0..1 across the ring's width.
	float radius = length(UV - vec2(0.5)) * 2.0;
	float across = (radius - inner) / (1.0 - inner);
	float band = 0.55 + 0.45 * sin(across * 37.0) * sin(across * 11.0 + 1.3);
	float edge = smoothstep(0.0, 0.06, across) * smoothstep(1.0, 0.9, across);
	ALBEDO = color * brightness * (0.6 + 0.4 * band);
	// The far half of the ring passes behind the planet.
	vec3 to_camera = normalize(local_camera - local_position);
	float along = dot(local_position, to_camera);
	float discriminant = along * along - (dot(local_position, local_position) - planet_radius * planet_radius);
	float hidden = (discriminant > 0.0 && sqrt(discriminant) - along > 0.0) ? 0.0 : 1.0;
	ALPHA = edge * band * 0.75 * opacity * hidden;
}
