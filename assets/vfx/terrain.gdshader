// Frontier terrain: sand on the flats, bare rock on slopes. Colours and detail
// come from world-space noise, so the mesh needs no texture coordinates of its own.
shader_type spatial;

uniform vec3 sand_color : source_color = vec3(0.55, 0.4, 0.28);
uniform vec3 rock_color : source_color = vec3(0.3, 0.24, 0.2);
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;

varying vec3 world_position;
varying float slope;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	slope = 1.0 - NORMAL.y;
}

void fragment() {
	float fine = texture(noise_texture, world_position.xz * 0.021).r;
	float broad = texture(noise_texture, world_position.xz * 0.0017).r;
	float huge = texture(noise_texture, world_position.xz * 0.00023).r;
	float rock = smoothstep(0.1, 0.32, slope + (fine - 0.5) * 0.12);
	vec3 sand = sand_color * (0.7 + 0.35 * broad + 0.3 * huge);
	vec3 stone = rock_color * (0.55 + 0.6 * fine + 0.35 * huge);
	ALBEDO = mix(sand, stone, rock);
	ROUGHNESS = mix(0.96, 0.86, rock);
	NORMAL_MAP = texture(detail_normal, world_position.xz * 0.045).rgb;
	// Detail fades with distance so far ground does not shimmer.
	NORMAL_MAP_DEPTH = mix(0.9, 0.0, smoothstep(150.0, 900.0, length(VERTEX)));
}
