# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [PlatformerMovementBase] for a side scrolling [CharacterBody2D].
## Horizontal movement is the x axis, vertical is along [member CharacterBody2D.up_direction].
## Only the x of the move input is used, up and down do nothing.
## Dependencies (body, collision_shape) are injected by the body.
## @note: [MovementProfile] values are in world units. The defaults are tuned for 3D
## meters, a 2D game in pixels needs its own profile.
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
		_disabled = true
		set_physics_process(false)
		return
	if not collision_shape:
		return
	_standing_shape_position = collision_shape.position
	_shape = collision_shape.shape
	if not (_shape is CapsuleShape2D or _shape is RectangleShape2D):
		push_error("%s: crouch needs a CapsuleShape2D or RectangleShape2D, the shape stays standing size" % name)
		_shape = null
		return
	# Own copy: the height changes at runtime and the scene's shape resource is shared by every instance.
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
	return Vector2(facing_component.facing.x, 0.0)


func _get_horizontal_velocity() -> Vector2:
	return Vector2(body.velocity.x, 0.0)


func _set_horizontal_velocity(value: Vector2) -> void:
	body.velocity.x = value.x


func _get_vertical_velocity() -> float:
	return body.velocity.dot(body.up_direction)


func _set_vertical_velocity(value: float) -> void:
	body.velocity += body.up_direction * (value - body.velocity.dot(body.up_direction))


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


# Resizes the shape instead of scaling the node, so the bottom can be kept at the feet.
func _set_crouched(crouched: bool) -> void:
	if not _shape:
		return
	var height: float = _standing_height
	if crouched:
		height = maxf(_standing_height * profile.crouch_collision_scale, _min_shape_height())
	_set_shape_height(height)
	# 2D y points down, so the shape moves down by half the lost height to keep the bottom at the feet.
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


# A capsule cannot be shorter than its two caps.
func _min_shape_height() -> float:
	if _shape is CapsuleShape2D:
		return (_shape as CapsuleShape2D).radius * 2.0
	return 0.0
