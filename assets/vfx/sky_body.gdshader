// A planet or moon in the sky, lit from a fixed direction. It is drawn without
// engine lighting or fog, so it always looks like it sits far beyond the atmosphere.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 light_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 color_a : source_color = vec3(0.8);
uniform vec3 color_b : source_color = vec3(0.5);
// 0 = cratered moon, above 0 = gas giant with this many cloud bands.
uniform float bands = 0.0;
uniform float brightness = 1.0;
// How solid the unlit side is: 0 by day (it vanishes into the sky), 1 at night.
uniform float dark_side = 0.0;

varying vec3 local_normal;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return value_noise(p) * 0.5 + value_noise(p * 2.1) * 0.3 + value_noise(p * 4.3) * 0.2;
}

void vertex() {
	local_normal = NORMAL;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(local_normal);
	float pattern;
	if (bands > 0.0) {
		float swirl = fbm(n * vec3(2.0, 6.0, 2.0) + 4.0) - 0.5;
		pattern = sin((n.y + swirl * 0.12) * bands * 3.14159) * 0.5 + 0.5;
		pattern = mix(pattern, fbm(n * 9.0 + 2.0), 0.2);
	} else {
		pattern = fbm(n * 5.0);
		pattern = mix(pattern, smoothstep(0.45, 0.6, fbm(n * 2.0 + 7.0)), 0.5);
	}
	vec3 surface = mix(color_b, color_a, pattern);
	float lit = smoothstep(-0.08, 0.3, dot(normalize(world_normal), normalize(light_direction)));
	// Thin haze on the limb.
	float limb = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = (surface * (1.0 - limb * 0.4) + color_a * limb * 0.5) * lit * brightness;
	ALPHA = mix(dark_side, 1.0, lit) * smoothstep(0.0, 0.08, dot(NORMAL, VIEW));
}
