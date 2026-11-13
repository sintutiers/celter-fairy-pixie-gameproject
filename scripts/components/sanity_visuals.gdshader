// SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
// SPDX-License-Identifier: EUPL-1.2
// Greys and darkens the screen edges, driven by SanityVisualsComponent.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// 0 = untouched, 1 = full effect.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
	// Rec. 601 luma weights.
	float grey = dot(screen, vec3(0.299, 0.587, 0.114));
	float vignette = smoothstep(0.3, 0.9, distance(SCREEN_UV, vec2(0.5)));
	COLOR = vec4(mix(screen, vec3(grey), strength) * (1.0 - vignette * strength), 1.0);
}
