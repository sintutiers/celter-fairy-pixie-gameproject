# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [PlatformerMovementBase] for side scrolling [CharacterBody2D].
## Horizontal movement is x axis, vertical is along [member CharacterBody2D.up_direction].
## Only x of move input is used, up + down do ∅.
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
var _standing_width: float


func _on_setup() -> void:
	super()
	if not _require_dependencies({ "body": body }):
		_disable_movement()
		return
	if not collision_shape:
		Log.error("%s: no collision_shape, crouch keeps the standing size" % name)
		return
	_standing_shape_position = collision_shape.position
	_shape = collision_shape.shape
	if not (_shape is CapsuleShape2D or _shape is RectangleShape2D):
		Log.error(
			"%s: crouch needs a CapsuleShape2D or RectangleShape2D, the shape stays standing size"
			% name
		)
		_shape = null
		return
	# own copy: height changes at runtime + scene shape resource is shared by every instance
	_shape = _shape.duplicate()
	collision_shape.shape = _shape
	_standing_height = _get_collision_shape_height()
	_standing_width = _get_collision_shape_width()


func _get_gravity_magnitude() -> float:
	return -body.get_gravity().dot(body.up_direction)


func _get_movement_input(frame: InputFrame) -> Vector2:
	return Vector2(frame.move.x, 0.0)


func _convert_input_direction_to_world(direction: Vector2) -> Vector2:
	return Vector2(direction.x, 0.0)


func _get_default_dash_direction() -> Vector2:
	return Vector2(facing, 0.0)


func _get_horizontal_velocity() -> Vector2:
	return Vector2(body.velocity.x, 0.0)


func _set_horizontal_velocity(value: Vector2) -> void:
	body.velocity.x = value.x


func _get_vertical_velocity() -> float:
	return body.velocity.dot(body.up_direction)


func _set_vertical_velocity(value: float) -> void:
	# up_direction is always normalized, which slide() requires
	body.velocity = body.velocity.slide(body.up_direction) + body.up_direction * value


func _get_wall_normal() -> Vector2:
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


# resizes shape, not scaling node ∴ bottom stays at feet
func _set_collision_shape_crouched(crouched: bool) -> void:
	if not _shape:
		return
	var height: float = _standing_height
	var width: float = _standing_width
	if crouched:
		width = _standing_width * profile.crouch_radius_scale
		height = maxf(
			_standing_height * profile.crouch_collision_scale,
			_get_minimum_collision_shape_height(width),
		)
	_set_collision_shape_width(width)
	_set_collision_shape_height(height)
	# 2D y points down ∴ move shape down by half lost height to keep bottom at feet
	collision_shape.position.y = _standing_shape_position.y + (_standing_height - height) * 0.5


func _get_collision_shape_height() -> float:
	if _shape is CapsuleShape2D:
		return (_shape as CapsuleShape2D).height
	return (_shape as RectangleShape2D).size.y


func _set_collision_shape_height(height: float) -> void:
	if _shape is CapsuleShape2D:
		(_shape as CapsuleShape2D).height = height
	else:
		(_shape as RectangleShape2D).size.y = height


func _get_collision_shape_width() -> float:
	if _shape is CapsuleShape2D:
		return (_shape as CapsuleShape2D).radius * 2.0
	return (_shape as RectangleShape2D).size.x


func _set_collision_shape_width(width: float) -> void:
	if _shape is CapsuleShape2D:
		(_shape as CapsuleShape2D).radius = width * 0.5
	else:
		(_shape as RectangleShape2D).size.x = width


# capsule cannot be shorter than its two caps
func _get_minimum_collision_shape_height(width: float) -> float:
	if _shape is CapsuleShape2D:
		return width
	return 0.0


# standing shape query, shrunk by SKIN ∴ floor + walls touching crouched shape dont block
func _has_room_to_stand() -> bool:
	if not _shape:
		return true
	# pixels, raise if standing up is refused next to walls, lower if low ceilings let you stand
	const SKIN: float = 0.5
	var standing: Shape2D = _shape.duplicate()
	var height: float = _standing_height - SKIN * 2.0
	var width: float = _standing_width - SKIN * 2.0
	if standing is CapsuleShape2D:
		(standing as CapsuleShape2D).radius = width * 0.5
		(standing as CapsuleShape2D).height = height
	else:
		(standing as RectangleShape2D).size = Vector2(width, height)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = standing
	query.transform = body.global_transform * Transform2D(0.0, _standing_shape_position)
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
