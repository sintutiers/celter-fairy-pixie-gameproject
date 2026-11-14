# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Tracks which way character faces.
## Feed it with [method update_facing_from_input] every frame.
class_name FacingComponent
extends Component

## Emitted when facing changes.
signal flipped(new_facing_x: float)

## Initial horizontal facing.
@export var default_facing_right: bool = true

## Last non-zero horizontal direction: -1 left, 1 right.
var facing: float


## [param direction] is raw input. Zero x keeps old facing.
func update_facing_from_input(direction: Vector2) -> void:
	if is_zero_approx(direction.x):
		return
	var x: float = signf(direction.x)
	if x != facing:
		flipped.emit(x)
	facing = x


func _on_setup() -> void:
	facing = 1.0 if default_facing_right else -1.0
