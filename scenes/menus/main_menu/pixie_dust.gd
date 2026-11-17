# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Floating specks behind menus. Keeps emission area covering whole screen when window resizes.
class_name PixieDust
extends CPUParticles2D


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()


func _fit_to_screen() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	position = screen_size / 2.0
	emission_rect_extents = screen_size / 2.0
