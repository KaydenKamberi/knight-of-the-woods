shader_type canvas_item;

// First-person helmet view (PRD C-2): dark helmet metal covers the screen
// except for a horizontal eye slit, with a lighter rim along the slit's edge.

uniform vec3 metal_color : source_color = vec3(0.09, 0.10, 0.12);
uniform vec3 rim_color : source_color = vec3(0.36, 0.38, 0.42);
// Middle of the slit: 0 is the top of the screen, 1 the bottom.
uniform float slit_center = 0.45;
// Height of the slit at the middle of the screen, as a fraction of screen height.
uniform float slit_height = 0.36;
// How much the slit narrows towards the left and right edges (0 = straight).
uniform float side_taper = 0.35;
uniform float edge_softness = 0.01;
uniform float rim_width = 0.025;

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float half_height = slit_height * 0.5 * (1.0 - side_taper * x * x);
	// Positive outside the slit (on the metal), negative inside it.
	float dist = abs(UV.y - slit_center) - half_height;
	float metal = smoothstep(-edge_softness, edge_softness, dist);
	// The far left and right edges fade into the helmet's sides.
	metal = max(metal, smoothstep(0.82, 1.0, abs(x)));
	float rim = 1.0 - smoothstep(0.0, rim_width, max(dist, 0.0));
	COLOR = vec4(mix(metal_color, rim_color, rim * 0.6), metal);
}
