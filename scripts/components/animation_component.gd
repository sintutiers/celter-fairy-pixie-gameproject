# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
## Picks sprite animation from [PlatformerMovementBase] and [FacingComponent] signals.
## Dependencies (sprite, movement_component, facing_component) are injected by body, all required.
## Sprite can be [AnimatedSprite3D] or [AnimatedSprite2D].
class_name AnimationComponent
extends Component

@export_group("Flip")
## Seconds for full turn squash.
@export var flip_duration: float = 0.1

## [AnimatedSprite3D] or [AnimatedSprite2D]. Typed [Node] because they share no base class.
var sprite: Node
var movement_component: PlatformerMovementBase
var facing_component: FacingComponent

var _is_airborne: bool = false
# Landing animation is playing. Ground motion changes are held back until it ends.
var _is_landing: bool = false
# Tumbling (airspin) must not be replaced by falling loop.
var _is_tumbling: bool = false
var _pending_ground_motion: StringName = Animations.IDLE
var _flip_tween: Tween
var _base_scale_x: float = 1.0


func _on_setup() -> void:
	var dependencies := {
		"sprite": sprite,
		"movement_component": movement_component,
		"facing_component": facing_component,
	}
	if not _require_dependencies(dependencies):
		return
	_base_scale_x = sprite.scale.x
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	movement_component.ground_motion_changed.connect(_on_ground_motion_changed)
	movement_component.jumped.connect(_on_jumped)
	movement_component.wall_jumped.connect(_on_wall_jumped)
	movement_component.landed.connect(_on_landed)
	movement_component.wall_slid.connect(_on_wall_slid)
	movement_component.fell_from_wall.connect(_on_fell_from_wall)
	movement_component.dashed.connect(_on_dashed)
	movement_component.started_falling.connect(_on_started_falling)
	facing_component.flipped.connect(_on_facing_flipped)
	sprite.flip_h = not facing_component.default_facing_right


# Every airborne animation sets same two flags.
func _play_airborne_animation(animation: StringName, tumbling: bool = false) -> void:
	_is_airborne = true
	_is_tumbling = tumbling
	sprite.play(animation)


func _on_ground_motion_changed(motion: StringName) -> void:
	if _is_landing:
		# Moving cuts landing short, anything else waits for it to finish.
		if motion == Animations.WALK or motion == Animations.RUN:
			_is_landing = false
			sprite.play(motion)
			return
		_pending_ground_motion = motion
		return
	if _is_airborne:
		return
	sprite.play(motion)


func _on_jumped(jump_number: int) -> void:
	_play_airborne_animation(Animations.JUMP if jump_number == 1 else Animations.AIRSPIN, jump_number != 1)


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
	# Already moving on touchdown (direction held through jump): motion never
	# changes while landing plays, so nothing would cut it short. Skip it.
	if motion == Animations.WALK or motion == Animations.RUN:
		_is_landing = false
		sprite.play(motion)
		return
	_is_landing = true
	sprite.play(Animations.LAND)


func _on_started_falling() -> void:
	if _is_tumbling:
		return
	_is_airborne = true
	sprite.play(Animations.FALLING)


func _on_sprite_animation_finished() -> void:
	if sprite.animation != Animations.LAND:
		return
	_is_landing = false
	sprite.play(_pending_ground_motion)


func _on_facing_flipped(new_facing_x: float) -> void:
	var flip: bool = new_facing_x < 0.0
	if _flip_tween:
		_flip_tween.kill()
	# Squash x to 0, swap flip at midpoint, expand back.
	_flip_tween = create_tween()
	_flip_tween.tween_property(sprite, "scale:x", 0.0, flip_duration * 0.5)
	_flip_tween.tween_callback(
		func() -> void:
			sprite.flip_h = flip,
	)
	_flip_tween.tween_property(sprite, "scale:x", _base_scale_x, flip_duration * 0.5)
