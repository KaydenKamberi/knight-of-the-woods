shader_type spatial;
render_mode specular_disabled;

// The game's one toon shader (PRD M7 art pass). Used on everything solid:
// trees, rocks, the castle, the furnace, characters and weapons.
//
// - Lighting comes in 3 bands (shadow, mid, lit), or 2 on the Low setting.
// - The shadow side is tinted blue-green, never black.
// - Characters get a soft rim light so they stand out.
// - flash: a short white flash when something is hit.
// - sway: leaves move in the wind (driven by world_time, so it slows with time).
// - distance_fade: scenery dissolves out near the view distance (a dither, so no
//   transparency is needed; works on the Compatibility renderer and iPhone).
//
// The shared settings are global shader parameters, set from game_config.gd
// (TOON_* and PALETTE) by the Graphics autoload.

global uniform vec4 toon_shadow_tint;
global uniform float toon_shadow_fill;
global uniform float toon_mid_level;
global uniform float toon_threshold_low;
global uniform float toon_threshold_high;
global uniform float toon_softness;
global uniform float toon_steps;
global uniform float toon_rim;
global uniform vec4 toon_rim_color;
global uniform float world_time;
global uniform float leaf_sway;
global uniform float fade_start;
global uniform float fade_end;

uniform vec4 albedo : source_color = vec4(1.0);
// MultiMesh instances can tint each copy (trees, rocks).
uniform bool use_instance_color = false;
uniform float rim_strength = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float flash = 0.0;
// How much this sways in the wind (leaves). Parts below sway_from metres don't move.
uniform float sway = 0.0;
uniform float sway_from = 1.2;
uniform bool distance_fade = false;

void vertex() {
	if (sway > 0.0 && leaf_sway > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float height = max(VERTEX.y - sway_from, 0.0);
		float wave = sin(world_time * 1.6 + world.x * 0.35 + world.z * 0.25)
				+ 0.5 * sin(world_time * 2.7 + world.x * 0.9);
		VERTEX.x += wave * 0.05 * height * sway * leaf_sway;
		VERTEX.z += wave * 0.03 * height * sway * leaf_sway;
	}
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_instance_color) {
		base *= COLOR.rgb;
	}
	if (distance_fade) {
		float view_distance = length(VERTEX);
		float keep = clamp((fade_end - view_distance) / max(fade_end - fade_start, 0.001), 0.0, 1.0);
		// Interleaved gradient noise: a fine, even dither pattern.
		float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (keep < noise) {
			discard;
		}
	}
	ALBEDO = mix(base, vec3(1.0), flash);
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength * toon_rim;
	EMISSION = emission_color.rgb * emission_energy + toon_rim_color.rgb * rim + vec3(flash * 0.5);
}

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float soft = toon_softness;
	float band = smoothstep(toon_threshold_low - soft, toon_threshold_low + soft, lit);
	if (toon_steps > 2.5) {
		float high = smoothstep(toon_threshold_high - soft, toon_threshold_high + soft, lit);
		band = band * toon_mid_level + high * (1.0 - toon_mid_level);
	}
	// The unlit side still gets a little blue-green light, so shadows are never black.
	vec3 amount = mix(toon_shadow_tint.rgb * toon_shadow_fill, vec3(1.0), band);
	if (!LIGHT_IS_DIRECTIONAL) {
		// Lamps and fires only reach as far as their range.
		amount *= clamp(ATTENUATION * 4.0, 0.0, 1.0);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * amount / PI;
}
