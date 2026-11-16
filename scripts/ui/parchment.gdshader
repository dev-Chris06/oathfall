shader_type canvas_item;
// Page de parchemin : grain, taches, bords brunis, et ombre de la reliure
// du côté du pli (`spine` : -1 à gauche, 1 à droite, 0 sans pli).

uniform vec4 paper : source_color = vec4(0.78, 0.69, 0.53, 1.0);
uniform vec4 burnt : source_color = vec4(0.36, 0.25, 0.14, 1.0);
uniform float spine = 0.0;
uniform vec2 page_size = vec2(540.0, 600.0);
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 px = UV * page_size;
	float grain = fbm(px / 7.0);
	float blotch = fbm(px / 120.0 + 3.7);

	// Distance au bord le plus proche, irrégulière.
	float edge = min(min(px.x, page_size.x - px.x), min(px.y, page_size.y - px.y));
	edge += (fbm(px / 25.0) - 0.5) * 18.0;
	float burn = 1.0 - smoothstep(0.0, 46.0, edge);

	vec3 color = paper.rgb * (0.9 + 0.16 * grain);
	color = mix(color, burnt.rgb, smoothstep(0.55, 0.85, blotch) * 0.22);
	color = mix(color, burnt.rgb, burn * 0.75);

	// Le creux de la reliure.
	if (spine != 0.0) {
		float from_spine = spine > 0.0 ? page_size.x - px.x : px.x;
		color *= mix(0.55, 1.0, smoothstep(0.0, 70.0, from_spine));
	}
	COLOR = vec4(color, 1.0);
}
