# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [PlatformerMovementBase] for [CharacterBody3D].
## Horizontal movement is x/z plane, vertical is along [member CharacterBody3D.up_direction].
## Dependencies (body, collision_shape) are injected by body.
class_name Movement3DComponent
extends PlatformerMovementBase

var body: CharacterBody3D
var collision_shape: CollisionShape3D

var _standing_shape_position: Vector3
var _capsule: CapsuleShape3D
var _standing_height: float
var _standing_radius: float


func _on_setup() -> void:
	super()
	if not _require_dependencies({ "body": body }):
		_disable_movement()
		return
	if not collision_shape:
		Log.error("%s: no collision_shape, crouch keeps the standing size" % name)
		return
	_standing_shape_position = collision_shape.position
	_capsule = collision_shape.shape as CapsuleShape3D
	if not _capsule:
		Log.error("%s: crouch needs a CapsuleShape3D, the shape stays standing size" % name)
		return
	# own copy: height changes at runtime + scene shape resource is shared by every instance
	_capsule = _capsule.duplicate()
	collision_shape.shape = _capsule
	_standing_height = _capsule.height
	_standing_radius = _capsule.radius


func _get_gravity_magnitude() -> float:
	return -body.get_gravity().dot(body.up_direction)


func _get_movement_input(frame: InputFrame) -> Vector2:
	return frame.move


func _convert_input_direction_to_world(direction: Vector2) -> Vector2:
	var world: Vector3 = body.global_basis * Vector3(direction.x, 0.0, direction.y)
	return Vector2(world.x, world.z)


func _get_default_dash_direction() -> Vector2:
	return _convert_input_direction_to_world(Vector2.UP)


func _get_horizontal_velocity() -> Vector2:
	return Vector2(body.velocity.x, body.velocity.z)


func _set_horizontal_velocity(value: Vector2) -> void:
	body.velocity.x = value.x
	body.velocity.z = value.y


func _get_vertical_velocity() -> float:
	return body.velocity.dot(body.up_direction)


func _set_vertical_velocity(value: float) -> void:
	# up_direction is always normalized, which slide() requires
	body.velocity = body.velocity.slide(body.up_direction) + body.up_direction * value


func _get_wall_normal() -> Vector2:
	var normal: Vector3 = body.get_wall_normal()
	return Vector2(normal.x, normal.z)


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


# resizes capsule, not scaling node: Jolt only scales capsules uniformly,
# ∴ y scale left bottom below feet + lifted body off floor
func _set_collision_shape_crouched(crouched: bool) -> void:
	if not _capsule:
		return
	var height: float = _standing_height
	var radius: float = _standing_radius
	if crouched:
		radius = _standing_radius * profile.crouch_radius_scale
		# capsule cannot be shorter than its two caps
		height = maxf(_standing_height * profile.crouch_collision_scale, radius * 2.0)
	_capsule.radius = radius
	_capsule.height = height
	# lowered by half lost height ∴ bottom stays at feet
	collision_shape.position.y = _standing_shape_position.y - (_standing_height - height) * 0.5


# standing capsule query, shrunk by SKIN ∴ floor + walls touching crouched capsule dont block
func _has_room_to_stand() -> bool:
	if not _capsule:
		return true
	# meters, raise if standing up is refused next to walls, lower if low ceilings let you stand
	const SKIN: float = 0.02
	var standing: CapsuleShape3D = CapsuleShape3D.new()
	standing.radius = _standing_radius - SKIN
	standing.height = _standing_height - SKIN * 2.0
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	query.transform = body.global_transform * Transform3D(Basis.IDENTITY, _standing_shape_position)
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
