shader_type canvas_item;
// Animated open-ocean backdrop drawn beneath the hex map.

uniform vec4 deep_color : source_color = vec4(0.012, 0.035, 0.08, 1.0);
uniform vec4 light_color : source_color = vec4(0.03, 0.1, 0.19, 1.0);
uniform vec2 size = vec2(2000.0, 1200.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * size / 110.0;
	float t = TIME * 0.12;
	float n = vnoise(p + vec2(t, t * 0.7)) * 0.6 + vnoise(p * 2.1 - vec2(t * 1.4, -t)) * 0.4;
	float waves = sin(p.x * 1.6 + p.y * 0.8 + TIME * 0.7 + n * 5.0);
	float crest = smoothstep(0.9, 1.0, waves) * (0.5 + 0.5 * vnoise(p * 3.0 + TIME * 0.2));
	vec3 col = mix(deep_color.rgb, light_color.rgb, n * 0.55);
	col += crest * vec3(0.2, 0.75, 0.9) * 0.3;
	// Faint magenta and cyan city-light reflections drifting on the swell.
	float glow = vnoise(p * 0.35 + vec2(TIME * 0.02, 0.0));
	col += vec3(0.25, 0.05, 0.2) * smoothstep(0.72, 1.0, glow) * 0.18;
	COLOR = vec4(col, 1.0);
}
