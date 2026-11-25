# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Picks sprite animation from [PlatformerMovementBase] signals.
## Dependencies (sprite, movement_component) are injected by body, all required.
## Sprite can be [AnimatedSprite3D]/[AnimatedSprite2D].
class_name AnimationComponent
extends Component

@export_group("Flip")
## Seconds for full turn squash.
@export var flip_duration: float = 0.1

## [AnimatedSprite3D]/[AnimatedSprite2D]. Typed [Node] ∵ they share no base class.
var sprite: Node
var movement_component: PlatformerMovementBase

var _is_airborne: bool = false
# landing animation playing, ground motion changes held back until it ends
var _is_landing: bool = false
# tumbling (airspin) must not be replaced by falling loop
var _is_tumbling: bool = false
var _pending_ground_motion: StringName = Animations.IDLE
var _flip_tween: Tween
var _base_scale_x: float = 1.0


func _on_setup() -> void:
	var dependencies: Dictionary = { "sprite": sprite, "movement_component": movement_component }
	if not _require_dependencies(dependencies):
		return
	_base_scale_x = _get_sprite_scale_x()
	sprite.connect(&"animation_finished", _on_sprite_animation_finished)
	movement_component.ground_motion_changed.connect(_on_ground_motion_changed)
	movement_component.jumped.connect(_on_jumped)
	movement_component.wall_jumped.connect(_on_wall_jumped)
	movement_component.landed.connect(_on_landed)
	movement_component.wall_slid.connect(_on_wall_slid)
	movement_component.fell_from_wall.connect(_on_fell_from_wall)
	movement_component.dashed.connect(_on_dashed)
	movement_component.started_falling.connect(_on_started_falling)
	movement_component.flipped.connect(_on_facing_flipped)
	_set_sprite_flip_h(not movement_component.default_facing_right)


func _play_airborne_animation(animation: StringName, tumbling: bool = false) -> void:
	_is_airborne = true
	_is_tumbling = tumbling
	_play_sprite_animation(animation)


func _on_ground_motion_changed(motion: StringName) -> void:
	if _is_landing:
		# moving cuts landing short, anything else waits for it
		if motion == Animations.WALK or motion == Animations.RUN:
			_is_landing = false
			_play_sprite_animation(motion)
			return
		_pending_ground_motion = motion
		return
	if _is_airborne:
		return
	_play_sprite_animation(motion)


func _on_jumped(jump_count: int) -> void:
	_play_airborne_animation(Animations.JUMP if jump_count == 1 else Animations.AIRSPIN, jump_count != 1)


func _on_wall_jumped() -> void:
	_play_airborne_animation(Animations.JUMP)


func _on_fell_from_wall() -> void:
	_play_airborne_animation(Animations.AIRSPIN, true)


func _on_wall_slid() -> void:
	_play_airborne_animation(Animations.WALL_SLIDE)


func _on_dashed() -> void:
	_play_airborne_animation(Animations.DASH)


func _on_landed(motion: StringName) -> void:
	_is_airborne = false
	_is_tumbling = false
	_pending_ground_motion = motion
	# already moving on touchdown: motion wont change during landing to cut it short ∴ skip it
	if motion == Animations.WALK or motion == Animations.RUN:
		_is_landing = false
		_play_sprite_animation(motion)
		return
	_is_landing = true
	_play_sprite_animation(Animations.LAND)


func _on_started_falling() -> void:
	if _is_tumbling:
		return
	_is_airborne = true
	_play_sprite_animation(Animations.FALLING)


func _on_sprite_animation_finished() -> void:
	if _get_sprite_animation() != Animations.LAND:
		return
	_is_landing = false
	_play_sprite_animation(_pending_ground_motion)


func _on_facing_flipped(new_facing_x: float) -> void:
	var is_facing_left: bool = new_facing_x < 0.0
	if _flip_tween:
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.tween_property(sprite, "scale:x", 0.0, flip_duration * 0.5)
	_flip_tween.tween_callback(_set_sprite_flip_h.bind(is_facing_left))
	_flip_tween.tween_property(sprite, "scale:x", _base_scale_x, flip_duration * 0.5)


# AnimatedSprite2D + 3D share no base class ∴ sprite is Node
# these four accessors are only unsafe access, both types have these members
func _play_sprite_animation(animation: StringName) -> void:
	sprite.play(animation)


func _get_sprite_animation() -> StringName:
	return sprite.animation


func _set_sprite_flip_h(flipped: bool) -> void:
	sprite.flip_h = flipped


func _get_sprite_scale_x() -> float:
	return sprite.scale.x
