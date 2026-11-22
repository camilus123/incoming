// Energy dome around the turret: a faint hex lattice that lights up in
// ripples where it is hit. Additive and very transparent at rest, because the
// player looks through it from the inside all the time.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

const int MAX_IMPACTS = 8;

uniform vec4 shield_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
// 0 = shield down, 1 = full.
uniform float charge = 1.0;
uniform float rest_alpha = 0.004;
// Hexagon cells per radian of sky, measured straight overhead.
uniform float hex_scale = 16.0;
// Whole-dome flash when the shield breaks or comes back.
uniform float flash = 0.0;
// xyz = direction from the dome centre to the impact (unit), w = age in seconds (< 0 = unused).
uniform vec4 impacts[MAX_IMPACTS];
// Number of leading entries of impacts that are in use (0 skips the loop entirely).
uniform int impact_count = 0;
uniform float ripple_speed = 1.4;   // radians per second across the dome
uniform float ripple_life = 0.9;    // seconds

varying vec3 local_direction;

void vertex() {
	local_direction = normalize(VERTEX);
}

// Distance to the nearest hexagon edge: 0 at a cell centre, 0.5 on an edge.
float hex_distance(vec2 uv) {
	vec2 grid = vec2(1.0, 1.7320508);
	vec2 half_grid = grid * 0.5;
	vec2 a = mod(uv, grid) - half_grid;
	vec2 b = mod(uv - half_grid, grid) - half_grid;
	vec2 cell = dot(a, a) < dot(b, b) ? a : b;
	cell = abs(cell);
	return max(dot(cell, normalize(grid)), cell.x);
}

void fragment() {
	vec3 direction = normalize(local_direction);
	// The dome ends at the ground: drop the mesh's flat base and fade the lowest part,
	// so the lattice never lies on the terrain when looking down.
	if (direction.y < 0.01) {
		discard;
	}
	float ground_fade = smoothstep(0.01, 0.12, direction.y);
	// Stereographic projection from the point under the turret: no pole, so the cells
	// stay regular hexagons everywhere (overhead included) and only grow gently
	// towards the ground. Longitude/latitude would pinch them together at the top.
	vec2 uv = direction.xz / (1.0 + direction.y) * 2.0 * hex_scale;
	float lattice = smoothstep(0.46, 0.5, hex_distance(uv));

	float glow = 0.0;
	for (int i = 0; i < impact_count; i++) {
		float age = impacts[i].w;
		float angle = acos(clamp(dot(direction, impacts[i].xyz), -1.0, 1.0));
		float ring_offset = angle - age * ripple_speed;
		float ring = exp(-ring_offset * ring_offset * 90.0);
		float core = exp(-angle * angle * 40.0);
		glow += (ring + core) * (1.0 - age / ripple_life);
	}

	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 4.0);
	float alpha = (rest_alpha * (0.3 + 2.5 * lattice) + rim * 0.01) * charge;
	alpha += glow * (0.12 + 0.88 * lattice) * 0.4;
	alpha += flash * (0.02 + 0.3 * lattice);
	ALBEDO = shield_color.rgb * 2.2;
	ALPHA = clamp(alpha * ground_fade, 0.0, 1.0);
}
