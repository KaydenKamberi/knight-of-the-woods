shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Grass blades (PRD M7 art pass), drawn by MultiMeshes across the forest floor.
// Darker at the base, lighter at the tips, swaying in waves of wind. The wind is
// driven by world_time, so it slows down when world time does. Blades dissolve
// out near the view distance like the rest of the scenery.

global uniform vec4 toon_shadow_tint;
global uniform float toon_shadow_fill;
global uniform float world_time;
global uniform float grass_wind;
global uniform float fade_start;
global uniform float fade_end;

uniform vec4 base_color : source_color = vec4(0.31, 0.54, 0.3, 1.0);
uniform vec4 tip_color : source_color = vec4(0.66, 0.82, 0.48, 1.0);
uniform float blade_height = 0.7;

varying float tip;

void vertex() {
	tip = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = (sin(world_time * 2.0 + world.x * 0.6 + world.z * 0.4)
			+ 0.5 * sin(world_time * 3.3 + world.x * 1.3)) * 0.22 * tip * tip * grass_wind;
	VERTEX.x += wave;
	VERTEX.z += wave * 0.5;
	// Light the blades as if they face up (they only ever turn around Y), so they
	// shade like the ground they grow from.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float view_distance = length(VERTEX);
	float keep = clamp((fade_end - view_distance) / max(fade_end - fade_start, 0.001), 0.0, 1.0);
	float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (keep < noise) {
		discard;
	}
	ALBEDO = mix(base_color.rgb, tip_color.rgb, tip) * COLOR.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float lit = clamp(ATTENUATION, 0.0, 1.0);
	vec3 amount = mix(toon_shadow_tint.rgb * toon_shadow_fill, vec3(1.0), 0.35 + 0.65 * lit);
	if (!LIGHT_IS_DIRECTIONAL) {
		amount *= clamp(ATTENUATION * 4.0, 0.0, 1.0);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * amount / PI;
}
