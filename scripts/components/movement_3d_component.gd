# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## [PlatformerMovementBase] for a [CharacterBody3D].
## Horizontal movement is the x/z plane, vertical is along [member CharacterBody3D.up_direction].
## Dependencies (body, collision_shape) are injected by the body.
class_name Movement3DComponent
extends PlatformerMovementBase

var body: CharacterBody3D
var collision_shape: CollisionShape3D

var _standing_shape_position: Vector3
var _capsule: CapsuleShape3D
var _standing_height: float


func _on_setup() -> void:
	super()
	if not collision_shape:
		return
	_standing_shape_position = collision_shape.position
	_capsule = collision_shape.shape as CapsuleShape3D
	if not _capsule:
		push_error("%s: crouch needs a CapsuleShape3D, the shape stays standing size" % name)
		return
	# Own copy: the height changes at runtime and the scene's shape resource is shared by every instance.
	_capsule = _capsule.duplicate()
	collision_shape.shape = _capsule
	_standing_height = _capsule.height


func _gravity() -> float:
	return -body.get_gravity().dot(body.up_direction)


func _read_move(frame: InputFrame) -> Vector2:
	return frame.move


# Input y maps to world z, rotated by the body's basis.
func _to_world(direction: Vector2) -> Vector2:
	var world: Vector3 = body.global_basis * Vector3(direction.x, 0.0, direction.y)
	return Vector2(world.x, world.z)


func _default_dash_direction() -> Vector2:
	return _to_world(Vector2.UP)


func _get_horizontal_velocity() -> Vector2:
	return Vector2(body.velocity.x, body.velocity.z)


func _set_horizontal_velocity(value: Vector2) -> void:
	body.velocity.x = value.x
	body.velocity.z = value.y


func _get_vertical_velocity() -> float:
	return body.velocity.dot(body.up_direction)


func _set_vertical_velocity(value: float) -> void:
	body.velocity += body.up_direction * (value - body.velocity.dot(body.up_direction))


func _wall_normal() -> Vector2:
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


# Resizes the capsule instead of scaling the node. Jolt only scales capsules uniformly,
# so a y scale left the bottom below the feet and lifted the body off the floor.
func _set_crouched(crouched: bool) -> void:
	if not _capsule:
		return
	var height: float = _standing_height
	if crouched:
		# A capsule cannot be shorter than its two caps.
		height = maxf(_standing_height * profile.crouch_collision_scale, _capsule.radius * 2.0)
	_capsule.height = height
	# Lowered by half the lost height, so the bottom stays at the feet.
	collision_shape.position.y = _standing_shape_position.y - (_standing_height - height) * 0.5
