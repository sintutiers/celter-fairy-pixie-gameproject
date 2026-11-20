# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Leans third person camera slightly toward mouse cursor. Camera keeps facing forward,
## cursor at screen edge turns it by <= [member max_degrees].
## Must be child of [PhantomCamera3D] in third person follow mode. Turns it through
## [method PhantomCamera3D.set_third_person_rotation_degrees], same as addon docs do for mouse look.
class_name CameraMouseLean
extends Node

## Turn at screen edge: x = up + down, y = left + right.
@export var max_degrees: Vector2 = Vector2(2.0, 4.0)
## Higher = catches up w/ cursor faster.
@export var smoothing: float = 4.0

var _lean: Vector2 = Vector2.ZERO

@onready var _camera: PhantomCamera3D = get_parent() as PhantomCamera3D
# forward direction lean is added to: camera rotation in level scene
# read here ∵ addon reparents camera under its spring arm after ready
@onready var _base_degrees: Vector3 = _camera.global_rotation_degrees if _camera else Vector3.ZERO


func _ready() -> void:
	if not _camera or _camera.get_follow_mode() != PhantomCamera3D.FollowMode.THIRD_PERSON:
		Log.error("%s: parent must be PhantomCamera3D in third person follow mode" % name)
		set_process(false)


func _process(delta: float) -> void:
	var viewport: Viewport = get_viewport()
	var half_size: Vector2 = viewport.get_visible_rect().size / 2.0
	var offset: Vector2 = ((viewport.get_mouse_position() - half_size) / half_size).clampf(-1.0, 1.0)
	var target: Vector2 = Vector2(-offset.y * max_degrees.x, -offset.x * max_degrees.y)
	_lean = _lean.lerp(target, 1.0 - exp(-smoothing * delta))
	_camera.set_third_person_rotation_degrees(_base_degrees + Vector3(_lean.x, _lean.y, 0.0))
