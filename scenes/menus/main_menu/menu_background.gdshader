// SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
// SPDX-License-Identifier: EUPL-1.2
// Night sky with slow violet fog drifting over it, darker at edges. Background for menus.
shader_type canvas_item;

uniform vec4 sky_top : source_color = vec4(0.004, 0.086, 0.153, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.105, 0.07, 0.16, 1.0);
uniform vec4 fog_color : source_color = vec4(0.63, 0.525, 0.62, 1.0);
// 0 = no fog, 1 = fog fully covers sky where it is thickest.
uniform float fog_strength : hint_range(0.0, 1.0) = 0.22;
uniform float fog_speed : hint_range(0.0, 0.2) = 0.02;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.75;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Layered noise, each layer smaller + fainter.
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	vec3 sky = mix(sky_top.rgb, sky_bottom.rgb, uv.y);
	// Two fog layers drift opposite ways, so it churns instead of scrolling.
	vec2 fog_uv = uv * vec2(3.0, 2.0);
	float fog = fbm(fog_uv + vec2(TIME * fog_speed, 0.0));
	fog = fbm(fog_uv + fog + vec2(-TIME * fog_speed * 0.7, TIME * fog_speed * 0.3));
	// Fog sits low, like it rises from the ground.
	fog *= smoothstep(0.1, 1.0, uv.y);
	vec3 color = mix(sky, fog_color.rgb, fog * fog_strength);
	float vignette = smoothstep(0.35, 0.95, distance(uv, vec2(0.5)));
	COLOR = vec4(color * (1.0 - vignette * vignette_strength), 1.0);
}
