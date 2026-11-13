# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [PlatformerMovementBase] for side scrolling [CharacterBody2D].
## Horizontal movement is x axis, vertical is along [member CharacterBody2D.up_direction].
## Only x of move input is used, up and down do nothing.
## Dependencies (body, collision_shape) are injected by body.
## [b]Note:[/b] [MovementProfile] values are in world units. Defaults are tuned for 3D
## meters, 2D game in pixels needs its own profile.
class_name Movement2DComponent
extends PlatformerMovementBase

var body: CharacterBody2D
var collision_shape: CollisionShape2D

var _standing_shape_position: Vector2
var _shape: Shape2D
var _standing_height: float


func _on_setup() -> void:
	super()
	if not _require({ "body": body }):
		_disable()
		return
	if not collision_shape:
		push_error("%s: no collision_shape, crouch keeps the standing size" % name)
		return
	_standing_shape_position = collision_shape.position
	_shape = collision_shape.shape
	if not (_shape is CapsuleShape2D or _shape is RectangleShape2D):
		push_error(
			"%s: crouch needs a CapsuleShape2D or RectangleShape2D, the shape stays standing size"
			% name
		)
		_shape = null
		return
	# Own copy: height changes at runtime and scene shape resource is shared by every instance.
	_shape = _shape.duplicate()
	collision_shape.shape = _shape
	_standing_height = _get_shape_height()


func _gravity() -> float:
	return -body.get_gravity().dot(body.up_direction)


func _read_move(frame: InputFrame) -> Vector2:
	return Vector2(frame.move.x, 0.0)


func _to_world(direction: Vector2) -> Vector2:
	return Vector2(direction.x, 0.0)


func _default_dash_direction() -> Vector2:
	return Vector2(facing_component.facing, 0.0)


func _get_horizontal_velocity() -> Vector2:
	return Vector2(body.velocity.x, 0.0)


func _set_horizontal_velocity(value: Vector2) -> void:
	body.velocity.x = value.x


func _get_vertical_velocity() -> float:
	return body.velocity.dot(body.up_direction)


func _set_vertical_velocity(value: float) -> void:
	# up_direction is always normalized, which slide() requires.
	body.velocity = body.velocity.slide(body.up_direction) + body.up_direction * value


func _wall_normal() -> Vector2:
	return Vector2(body.get_wall_normal().x, 0.0)


func _move_and_slide() -> void:
	body.move_and_slide()


func _is_on_floor() -> bool:
	return body.is_on_floor()


func _is_on_wall() -> bool:
	return body.is_on_wall()


func _is_on_wall_only() -> bool:
	return body.is_on_wall_only()


func _is_on_ceiling() -> bool:
	return body.is_on_ceiling()


# Resizes shape instead of scaling node, so bottom can be kept at feet.
func _set_crouched(crouched: bool) -> void:
	if not _shape:
		return
	var height: float = _standing_height
	if crouched:
		height = maxf(_standing_height * profile.crouch_collision_scale, _min_shape_height())
	_set_shape_height(height)
	# 2D y points down, so shape moves down by half lost height to keep bottom at feet.
	collision_shape.position.y = _standing_shape_position.y + (_standing_height - height) * 0.5


func _get_shape_height() -> float:
	if _shape is CapsuleShape2D:
		return (_shape as CapsuleShape2D).height
	return (_shape as RectangleShape2D).size.y


func _set_shape_height(height: float) -> void:
	if _shape is CapsuleShape2D:
		(_shape as CapsuleShape2D).height = height
	else:
		(_shape as RectangleShape2D).size.y = height


# Capsule cannot be shorter than its two caps.
func _min_shape_height() -> float:
	if _shape is CapsuleShape2D:
		return (_shape as CapsuleShape2D).radius * 2.0
	return 0.0
